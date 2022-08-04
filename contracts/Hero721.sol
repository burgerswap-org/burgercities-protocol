// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./lib/openzeppelin/contracts/utils/math/SafeCast.sol";
import "./lib/openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./lib/openzeppelin/contracts/access/Ownable.sol";
import "./lib/openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./Common.sol";


contract Hero721 is IHero721, ERC721Enumerable, Ownable, ReentrancyGuard
{
    using SafeCast for uint;

    address public heromanage;
    address public herobox;
    string base_token_uri;
    string suffix;

    uint16 constant max_creation = 10000;
    uint16 public creation_token_count = 0;

    mapping(uint32 => HeroMetaData) metadata_map;

    event CreateTo(address to, uint32 token_id, HeroMetaData meta);
    event Change(address owner, uint32 token_id, HeroMetaData meta);

    constructor() ERC721("BurgerCities Hero v1", "BurgerHero")
    {
    }

    function tokenURI(uint256 _token_id) public view virtual override returns (string memory)
    {
        require(_exists(_token_id), "invalid token id");
        return string(abi.encodePacked(base_token_uri, Strings.toString(_token_id), suffix));
    }

    function getTokens(address _account) public view returns (uint[] memory)
    {
        uint count = balanceOf(_account);
        uint[] memory tokens = new uint[](count);
        for(uint i = 0; i < count; i++) {
            uint token_id = tokenOfOwnerByIndex(_account, i);
            tokens[i] = token_id;
        }

        return tokens;
    }

    function getMetas(uint32[] memory _token_ids) public view returns (uint32[] memory, HeroMetaData[] memory)
    {
        HeroMetaData[] memory metas = new HeroMetaData[](_token_ids.length);
        for (uint256 i = 0; i < _token_ids.length; ++i) {
            require(_exists(_token_ids[i]), "invalid token id");

            metas[i] = metadata_map[_token_ids[i]];
        }

        return (_token_ids, metas);
    }

    function getMeta(uint32 _token_id) external view returns (HeroMetaData memory)
    {
        require(_exists(_token_id), "invalid token id");
        return metadata_map[_token_id];
    }

    function setMeta(uint32 _token_id, HeroMetaData calldata _meta) external nonReentrant
    {
        require(msg.sender == heromanage);
        require(_exists(_token_id), "invalid token id");

        metadata_map[_token_id] = _meta;
        emit Change(ownerOf(_token_id), _token_id, _meta);
    }

    function burn(uint32 _token_id) external nonReentrant
    {
        require(ownerOf(_token_id) == msg.sender, "only the owner can burn");

        _burn(_token_id);
        delete metadata_map[_token_id];
    }

    function exists(uint32 _token_id) public view returns(bool)
    {
        return _exists(_token_id);
    }

    function createCreationTo(address _to, HeroMetaData calldata _meta) external nonReentrant
    {
        require(msg.sender == herobox);
        require(creation_token_count + 1 <= max_creation, "up to max creation");

        uint32 new_token_id = ++creation_token_count;
        _safeMint(_to, new_token_id);

        metadata_map[new_token_id] = _meta;

        emit CreateTo(_to, new_token_id, _meta);
    }

    function createDescendantsTo(address _to, HeroMetaData calldata _meta) external nonReentrant
    {
        require(msg.sender == heromanage);

        uint descendants_token_count = totalSupply() - uint(creation_token_count) + uint(max_creation);
        ++descendants_token_count;
        uint32 new_token_id = descendants_token_count.toUint32(); 
        _safeMint(_to, new_token_id);

        metadata_map[new_token_id] = _meta;

        emit CreateTo(_to, new_token_id, _meta);
    }

    function calcCreationLimit() external view returns (uint16)
    {
        return (max_creation - creation_token_count);
    }

    function setHeroManage(address _heromanage) external onlyOwner
    {
        heromanage = _heromanage;
    }

    function setHeroBox(address _herobox) external onlyOwner
    {
        herobox = _herobox;
    }

    function setBaseTokenURI(string calldata _base_token_uri, string calldata _suffix) external onlyOwner
    {
        base_token_uri = _base_token_uri;
        suffix = _suffix;
    }
}
