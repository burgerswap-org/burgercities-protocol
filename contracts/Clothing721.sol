// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./lib/openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./lib/openzeppelin/contracts/access/Ownable.sol";
import "./lib/openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./Common.sol";

contract Clothing721 is IClothing721, ERC721Enumerable, Ownable, ReentrancyGuard
{
    address public manage_contract;
    string base_token_uri;
    string suffix;

    event MintTo(address to, uint token_id, uint32 clothes_id);

    constructor() ERC721("BurgerCities Clothing v1", "BurgerCities 2077")
    {
    }

    function tokenURI(uint256 _token_id) public view virtual override returns (string memory)
    {
        require(_exists(_token_id), "Invalid TokenId");
        return string(abi.encodePacked(base_token_uri, Strings.toString(_token_id), suffix));
    }

    function getTokens(address _account) external view returns (uint[] memory)
    {
        uint count = balanceOf(_account);
        uint[] memory tokens = new uint[](count);
        for (uint i = 0; i < count; i++) {
            uint token_id = tokenOfOwnerByIndex(_account, i);
            tokens[i] = token_id;
        }

        return tokens;
    }

    function exists(uint _token_id) external view returns(bool)
    {
        return _exists(_token_id);
    }

    function manageMintTo(address _to, uint32 _clothes_id) external nonReentrant
    {
        require(msg.sender == manage_contract);

        uint new_token_id = totalSupply();
        ++new_token_id;
        _safeMint(_to, new_token_id);

        emit MintTo(_to, new_token_id, _clothes_id);
    }

    function ownerMintTo(address _to, uint32 _clothes_id) external onlyOwner nonReentrant
    {
        uint new_token_id = totalSupply();
        ++new_token_id;
        _safeMint(_to, new_token_id);

        emit MintTo(_to, new_token_id, _clothes_id);
    }


    //*****************************************************************************
    //* manage
    //*****************************************************************************
    function kill() external onlyOwner
    {
        selfdestruct(payable(owner()));
    }

    function setManageContract(address _manage_contract) external onlyOwner
    {
        manage_contract = _manage_contract;
    }

    function setBaseTokenURI(string calldata _base_token_uri, string calldata _suffix) external onlyOwner
    {
        base_token_uri = _base_token_uri;
        suffix = _suffix;
    }
}
