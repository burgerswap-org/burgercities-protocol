// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./lib/openzeppelin/contracts/utils/Strings.sol";
import "./lib/openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./lib/openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./lib/Signature.sol";
import "./Configable.sol";

contract Props721 is ERC721, Configable {
    address immutable b_consumeToken;

    address public s_signer;
    uint256 public s_currentTokenId = 1;
    uint256 public s_consumeMintAmount;
    uint256 public s_consumeBurnAmount;
    string public s_baseURI;
    string public s_suffix;

    event Create(address indexed user, uint256 indexed tokenId, uint256 seed);

    constructor(
        string memory name,
        string memory symbol,
        string memory baseURI,
        string memory suffix,
        address signer,
        address consumeToken
    ) ERC721(name, symbol) {
        require(consumeToken != address(0) && signer != address(0), 'Invalid arg zero address');
        owner = msg.sender;
        b_consumeToken = consumeToken;
        s_signer = signer;
        s_baseURI = baseURI;
        s_suffix = suffix;
    }

    function setBaseURI(string memory baseURI, string memory suffix) external onlyDev {
        s_baseURI = baseURI;
        s_suffix = suffix;
    }

    function setConsumeAmount(uint256 consumeMintAmount, uint256 consumeBurnAmount) external onlyDev {
        s_consumeMintAmount = consumeMintAmount;
        s_consumeBurnAmount = consumeBurnAmount;
    }

    function setSigner(address signer) external onlyDev {
        require(s_signer != signer, 'Invalid arg no change');
        s_signer = signer;
    }

    function withdraw(address token, address to, uint256 amount) external onlyOwner {
        require(IERC20(token).balanceOf(address(this))  >= amount, 'Insufficient balance');
        IERC20(token).transfer(to, amount);
    }

    function mint(address account, uint256 expiryTime, uint256 seed, bytes memory signature) external {
        require(expiryTime > block.timestamp, "Invalid arg seed");
        require(account == msg.sender, "Invalid caller address");
        require(verify(msg.sender, expiryTime, seed, signature), "Invalid signature");
        
        if (s_consumeMintAmount > 0) {
            IERC20(b_consumeToken).transferFrom(msg.sender, address(this), s_consumeMintAmount);
        }
        uint256 tokenId = s_currentTokenId;
        _mint(msg.sender, tokenId);

        s_currentTokenId += 1;

        emit Create(msg.sender, tokenId, seed);
    }

    function burn(uint256 tokenId) external {
        if (s_consumeBurnAmount > 0) {
            IERC20(b_consumeToken).transferFrom(msg.sender, address(this), s_consumeBurnAmount);
        }
        _burn(tokenId);
    }

    function verify(address account, uint256 expiryTime, uint256 seed, bytes memory signatures) public view returns (bool) {
        bytes32 message = keccak256(abi.encodePacked(account, expiryTime, address(this), seed));
        bytes32 hash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
        address[] memory sign_list = Signature.recoverAddresses(hash, signatures);
        return sign_list[0] == s_signer;
    }

    function tokenURI(uint256 tokenId) public view override returns(string memory) {
        require(_exists(tokenId), "Invalid tokenId");
        return string(abi.encodePacked(s_baseURI, Strings.toString(tokenId), s_suffix));
    }

    function _baseURI() internal view override returns (string memory) {
        return s_baseURI;
    }
}