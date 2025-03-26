
## 1. 交易被用户使用eth_sendRawTransaction接口发送给执行层客户端，交易会如何被保存？
   Transaction 的执行主要在发生在两个 Workflow 中:
      1. Miner 在打包新的 Block 时。此时 Miner 会按 Block 中 Transaction 的打包顺
      序来执行其中的 Transaction。
      2. 其他节点添加 Block 到 Blockchain 时。当节点从网络中监听并获取到新的
      Block 时，它们会执行 Block 中的 Transaction，来更新本地的 State Trie 的
      Root，并与 Block Header 中的 State Trie Root 进行比较，来验证 Block 的合
      法性。

      一条 Transaction 执行，可能会涉及到多个 Account/Contract 的值的变化，最
   终造成一个或多个 Account 的 State 的发生转移。在 Byzantium 分叉之前的 Geth 版
   本中，在每个 Transaction 执行之后，都会计算一个当前的 State Trie Root，并写入
   到对应的 Transaction Receipt 中。这符合以太坊黄皮书中的原始设计。即交易是使
   得 Ethereum 状态机发生状态状态转移的最细粒度单位。
   
   读者们可能已经来开产生疑惑了，“每个 Transaction 都会重算一个 State Trie Root” 的方式岂不是会带来大量
   的计算 (重算一次一个 MPT Path 上的所有 Node) 和读写开销 (新生成的 MPT Node
   是很有可能最终被持久化到 LevelDB 中的)？
      结论是显然的。因此在 Byzantium 分叉之后，在一个 Block 的验证周期中只会计算一次的 State Root。我们仍然可以在
   state_processor.go 找寻到早年代码的痕迹。最终，一个 Block 中所有 Transaction
   执行的结果使得 World State 发生状态转移。
---

## 2. 交易被保存后，如何被选中？
   我们想要通过 Transaction 的 Hash 查询一个 Transaction 具体的数据的时
候，上层的 API 会调用 eth/api_backend.go 中的 GetTransaction() 函数，并最终调
用了 core/rawdb/accessors_indexes.go 中的 ReadTransaction() 函数来查询。
   在读取 Transaction 的时候，ReadTransaction() 函数首先
获取了保存该 Transaction 的函数 Block body，并循环遍历该 Block Body 中获取
到对应的 Transaction。这是因为，虽然 Transaction 是作为一个基本的数据结构
(Transaction Hash 可以保证 Transaction 的唯一性)，但是在写入数据库的时候就是
被按照 Block Body 的形式被整个的打包写入到 Database 中的。
---

## 3. 一个交易消耗的gas如何计算？是什么时候从sender账户扣除？
commitTransactions 函数进行计算gas
   首先这个函数会给 Block 设置最大可以使用的 Gas 的上限
   函数的主体是一个 For 循环
      params.TxGas 表示了 transaction 需要的最少的 Gas 的数量
      w.current.gasPool.Gas() 可以获取当前 block 剩余可以用的 Gas 的 Quota，如果剩余(这个后面看不到了)
   提交单条 Transaction 进行验证
接着执行commitTransaction() 函数
ApplyTransaction() 函数
applyTransaction() 函数
ApplyMessage() 函数
TransitionDb() 函数
all() 函数
最后执行Run() 函数，这个函数会执行一个UseGas()函数它会对gas quota进行判断:
   当前剩余的 gas quota 减去 input 参数。剩余的 gas 小于 input 直接返回 false;否则当前的 gas quota 减去 input 并返回 true

---

## 4. 创建合约交易和普通交易处理方式的区别？
   外部账户 (EOA) 是由用户直接控制的账户，负责签名并发起交易 (Transac-
tion)。用户通过控制 Account 的私钥来保证对账户数据的控制权。
   合约账户 (Contract)，简称为合约，是由外部账户通过 Transaction 创建的。合
约账户保存了不可篡改的图灵完备的代码段，以及一些持久化的数据变量。这些代码
使用专用的图灵完备的编程语言编写 (Solidity)，并通常提供一些对外部访问 API 接
口函数。这些 API 接口函数可以通过构造 Transaction，或者通过本地/第三方提供的
节点 RPC 服务来调用。这种模式构成了目前的 DApp 生态的基础。

   通常，合约中的函数用于计算以及查询或修改合约中的持久化数据。我们经常看
到这样的描述” 一旦被记录到区块链上数据不可被修改，或者不可篡改的智能合约”。
现在我们知道这种笼统的描述其实是不准确。针对一个链上的智能合约，不可修改/篡
改的部分是合约中的代码段，或说合约中的函数逻辑/代码逻辑是不可以被修改/篡改
的。而合约中的持久化的数据变量是可以通过调用代码段中的函数进行数据操作的
(CURD)。具体的操作方式取决于合约函数中的代码逻辑。
   根据合约中函数是否会修改合约中持久化的变量，合约中的函数可以分为两种:
只读函数和写函数。如果用户只希望查询某些合约中的持久化数据，而不对数据进
行修改的话，那么用户只需要调用相关的只读函数。调用只读函数不需要通过构造一
个 Transaction 来查询数据。用户可以通过直接调用本地节点或者第三方节点提供的
RPC 接口来直接调用对应的合约中的只读函数。如果用户需要对合约中的数据进行
更新，那么他就要构造一个 Transaction 来调用合约中相对应的写函数。注意，每个
Transaction 每次调用一个合约中的一个写函数。因为，如果想在链上实现复杂的逻
辑，需要将写函数接口化，在其中调用更多的逻辑。


   从数据层面讲，外部账户 (EOA) 与合约账户 (Contract) 不同的点在于: 外部账户
并没有维护自己的代码 (codeHash) 以及额外的 Storage 层。相比与外部账户，合约
账户额外保存了一个存储层 (Storage) 用于存储合约代码中持久化的变量的数据。在
上文中我们提到，StateObject 结构体中的声明的四个 Storage 类型的变量，就是作
为 Contract Storage 层的内存缓存。

| **对比项**       | **外部账户**                     | **普通交易**                     |
|------------------|----------------------------------|--------------------------------------|
| **数据层面讲**     | 有维护自己的代码以及额外的 Storage 层 | 额外保存了一个存储层 (Storage) 用于存储合约代码中持久化的变量的数据 |
| **目标**         | 用户通过控制 Account 的私钥来保证对账户数据的控制权  | 部署新合约到链上                       |
| **作用**         | 负责签名并发起交易               | 部署新合约到链上                       |

---
 
## 5. 创建合约有什么限制？

---

## 6. 交易是怎么被广播给其他执行层客户端的？

---

## 7. PoW(Proof of Work)与PoS(Proof of Stake)?

---

## 8. PoW时期，矿工如何赚取收益？收益什么时候被添加到账户？

---

## 9. PoW时期，如何产生一个新块？并把区块广播出去？

---

## 10. 合并到PoS后，新区块如何同步？