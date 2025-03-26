// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract XnnToken is ERC20{
    constructor() ERC20("XnnToken", "XNN") {
        _mint(msg.sender, 20000000*1_000_000_000_000_000_000);
    }
}
