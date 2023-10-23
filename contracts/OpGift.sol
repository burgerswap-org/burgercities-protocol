// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./Configable.sol";

contract OpGift is Configable, ERC721Enumerable, ReentrancyGuard {
    using Counters for Counters.Counter;

    Counters.Counter public counter;
    uint256 public endTimestamp;
    bool public mintable = true;
    string public metadataIpfs;

    mapping(address => bool) public userList;

    constructor(
        string memory name_,
        string memory symbol_,
        string memory metadataIpfs_,
        uint256 endTimestamp_
    ) ERC721(name_, symbol_) {
        require(endTimestamp_ > block.timestamp, "Invalid endTimestamp");
        metadataIpfs = metadataIpfs_;
        endTimestamp = endTimestamp_;
        owner = msg.sender;
    }

    function setMint(bool status) external onlyDev {
        mintable = status;
    }

    function setMetadata(string memory metadataIpfs_) external onlyDev {
        metadataIpfs = metadataIpfs_;
    }

    function setEndTimestamp(uint256 endTimestamp_) external onlyDev {
        endTimestamp = endTimestamp_;
    }

    function mint() external nonReentrant {
        require(mintable, "Mint func is deactivated");
        require(block.timestamp <= endTimestamp, "Activity is expired");
        require(!userList[msg.sender], "Each user only mint once.");
        uint256 tokenId = counter.current();
        _mint(msg.sender, tokenId);
        userList[msg.sender] = true;
        counter.increment();
    }

    function burn(uint256 tokenId) external {
        _burn(tokenId);
    }

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        return metadataIpfs;
    }
}
