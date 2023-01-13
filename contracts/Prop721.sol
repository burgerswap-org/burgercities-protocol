// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./lib/openzeppelin/contracts/access/Ownable.sol";
import "./lib/openzeppelin/contracts/utils/Strings.sol";
import "./lib/openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./lib/openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./lib/openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract Prop721 is ERC721Enumerable, Ownable, ReentrancyGuard {
    using Strings for uint256;

    address immutable b_consumeToken;
    uint256 public s_consumeAmount;
    string public s_baseURI;

    mapping(uint256 => string) private s_tokenURIs;

    constructor(
        string memory name,
        string memory symbol,
        string memory baseURI,
        address consumeToken, 
        uint256 consumeAmount
    ) ERC721(name, symbol) {
        require(consumeToken != address(0), 'Invalid arg zero address');
        b_consumeToken = consumeToken;
        s_baseURI = baseURI;
        s_consumeAmount = consumeAmount;
    }

    function setBaseURI(string memory baseURI) external onlyOwner {
        s_baseURI = baseURI;
    }

    function setConsumeAmount(uint256 consumeAmount) external onlyOwner {
        require(s_consumeAmount != consumeAmount, 'Invalid arg no change');
        s_consumeAmount = consumeAmount;
    }

    function withdraw(address token, address to, uint256 amount) external onlyOwner {
        require(IERC20(token).balanceOf(address(this))  >= amount, 'Insufficient balance');
        IERC20(token).transfer(to, amount);
    }

    function mint(address to, string memory _tokenURI) external {
        IERC20(b_consumeToken).transferFrom(msg.sender, address(this), s_consumeAmount);
        uint256 tokenId = totalSupply();
        _mint(to, tokenId);
        _setTokenURI(tokenId, _tokenURI);
    }

    function burn(uint256 tokenId) external {
        IERC20(b_consumeToken).transferFrom(msg.sender, address(this), s_consumeAmount);
        _burn(tokenId);
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "Invalid tokenId");

        string memory _tokenURI = s_tokenURIs[tokenId];
        string memory base = _baseURI();

        if (bytes(base).length == 0) {
            return _tokenURI;
        }

        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }

        return super.tokenURI(tokenId);
    }

    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
        require(_exists(tokenId), "Invalid tokenId");
        s_tokenURIs[tokenId] = _tokenURI;
    }

    function _burn(uint256 tokenId) internal virtual override {
        super._burn(tokenId);

        if (bytes(s_tokenURIs[tokenId]).length != 0) {
            delete s_tokenURIs[tokenId];
        }
    }

    function _baseURI() internal view override returns (string memory) {
        return s_baseURI;
    }
}