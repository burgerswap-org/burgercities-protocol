// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./lib/openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./lib/openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./lib/Signature.sol";
import "./Configable.sol";

contract HeroExchange is ReentrancyGuard, Configable {
    address immutable b_treasury; // burgercities 0xFc4C562e3271aD997A4330ae73F9af13b877aA8A;
    address immutable b_nft0; // binance nft 0x5DA38dEF924Ba7393f15fD0750Cd298206bfD150;
    address immutable b_nft1; // burgercities nft 0x20F8b9a461CAB48C065974ceb74e059f72EeD700;
    address public s_signer;

    event Exchange(address caller, uint tokenId0, uint tokenId1);

    constructor(address treasury, address nft0, address nft1, address signer) {
        require(treasury != address (0) && nft0 != address(0) && nft1 != address(0) && signer != address(0), "invalid params");
        b_treasury = treasury;
        b_nft0 = nft0;
        b_nft1 = nft1;
        s_signer = signer;
        owner = msg.sender;
    }

    function exchange(uint tokenId0, uint tokenId1, bytes memory signature) external nonReentrant {
        require(verify(tokenId0, tokenId1, signature), "invalid signatures");
        IERC721(b_nft0).transferFrom(msg.sender, address(this), tokenId0);
        IERC721(b_nft1).transferFrom(b_treasury, msg.sender, tokenId1);
        emit Exchange(msg.sender, tokenId0, tokenId1);
    }

    function setSigner(address signer) external onlyOwner {
        require(s_signer != signer && signer != address(0), "invalid signer");
        s_signer = signer;
    }

    function verify(
        uint tokenId0,
        uint tokenId1,
        bytes memory signature
    ) internal view returns (bool) {
        bytes32 message = keccak256(abi.encodePacked(tokenId0, tokenId1, address(this)));
        bytes32 hash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
        address[] memory signList = Signature.recoverAddresses(hash, signature);
        return signList[0] == s_signer;
    }
}