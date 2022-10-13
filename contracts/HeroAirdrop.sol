// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./lib/openzeppelin/contracts/access/Ownable.sol";
import "./lib/openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./lib/openzeppelin/contracts/token/ERC721/IERC721.sol";

contract HeroAirdrop is Ownable{
    uint8 constant s_index_max = 10;
    address immutable s_nft;
    address immutable s_treasury;
    
    uint256 public s_index;
    bytes32 public s_root;
    mapping(address => bool) public s_claimed;

    uint16[] private s_tokenIds;
    
    constructor(address nft, address treasury, bytes32 root, uint16[] memory tokenIds) {
        require(nft != address(0) && treasury != address(0), "Params of address type can not be zero");
        require(tokenIds.length == s_index_max, "Invalid tokenIds length");
        s_nft = nft;
        s_treasury = treasury;
        s_root = root;
        s_tokenIds = tokenIds;
    }

    function setRoot(bytes32 root) external onlyOwner {
        s_root = root;
    }

    function claim(bytes32[] memory proof) external {
        require(_check(msg.sender, proof), "Not in whitelist");
        require(!s_claimed[msg.sender], "Already claimed");
        require(s_index < s_index_max, "Airdrop finished");
        IERC721(s_nft).transferFrom(s_treasury, msg.sender, uint256(s_tokenIds[s_index]));
        s_claimed[msg.sender] = true;
        s_index += 1;
    }

    function checkWhiteList(bytes32[] memory proof) external view returns (bool) {
        return _check(msg.sender, proof);
    }

    function _check(address user, bytes32[] memory proof) internal view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(user));
        if (!MerkleProof.verify(proof, s_root, leaf)) return false;
        return true;
    }
}
