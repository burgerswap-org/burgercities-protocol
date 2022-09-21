// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../lib/openzeppelin/contracts/token/ERC721/ERC721.sol";

contract TestERC721 is ERC721 {
    uint256 public totalSupply;

    constructor() ERC721("TestERC721", "TERC721") {}

    function mint(uint256 amount, address to) external {
        for (uint256 i = 1; i <= amount; i++) {
            _mint(to, totalSupply + i);
        }
        totalSupply = totalSupply + amount;
    }
}
