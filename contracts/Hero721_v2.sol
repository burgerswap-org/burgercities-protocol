// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./lib/openzeppelin/contracts/utils/math/SafeCast.sol";
import "./lib/openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./lib/openzeppelin/contracts/access/Ownable.sol";
import "./lib/openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./Common.sol";

contract Hero721V2 is ERC721Enumerable, Ownable, ReentrancyGuard
{
    using SafeCast for uint;

    string base_token_uri;
    string suffix;
    mapping(address => bool) public whiteList;
    mapping(uint256 => HeroMetaDataV2) metadata_map;

    // [tokenId][keyId]=value
    mapping(uint256 => mapping(uint256 => uint256)) metadata_ext_map;
    uint256[] public ext_keys;
    

    event WhiteListChanged(address indexed _user, bool indexed _old, bool indexed _new);
    event HeroCreated(uint8 mint_type, address to, uint256 token_id, HeroMetaDataV2 meta, HeroMetaDataExt[] exts);
    event HeroChanged(address owner, uint256 token_id, HeroMetaDataV2 meta, HeroMetaDataExt[] exts);

    modifier onlyWhiteList() {
        require(whiteList[msg.sender], 'ONLY_WHITE_LIST');
        _;
    }

    constructor() ERC721("BurgerCities Hero V2", "BurgerHero")
    {
    }

    function tokenURI(uint256 _token_id) public view virtual override returns (string memory)
    {
        require(_exists(_token_id), "invalid token id");
        return string(abi.encodePacked(base_token_uri, Strings.toString(_token_id), suffix));
    }

    function getExtKeys() external view returns (uint256[] memory) {
        return ext_keys;
    }

    function existExtKey(uint256 _key) public view returns (bool) {
        for(uint256 i=0; i < ext_keys.length; i++) {
            if(ext_keys[i] == _key) return true;
        }
        return false;
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

    function getMetas(uint256[] memory _token_ids) public view returns (uint256[] memory, HeroMetaDataV2[] memory)
    {
        HeroMetaDataV2[] memory metas = new HeroMetaDataV2[](_token_ids.length);
        for (uint256 i = 0; i < _token_ids.length; ++i) {
            require(_exists(_token_ids[i]), "invalid token id");

            metas[i] = metadata_map[_token_ids[i]];
        }

        return (_token_ids, metas);
    }

    function getMeta(uint256 _token_id) external view returns (HeroMetaDataV2 memory)
    {
        require(_exists(_token_id), "invalid token id");
        return metadata_map[_token_id];
    }

    function getMetas2(uint256[] memory _token_ids) external view returns (uint256[] memory token_ids, HeroMetaDataV2[] memory metas, HeroMetaDataExt[][] memory exts)
    {
        token_ids = _token_ids;
        metas = new HeroMetaDataV2[](_token_ids.length);
        for (uint256 i = 0; i < _token_ids.length; ++i) {
            require(_exists(_token_ids[i]), "invalid token id");

            metas[i] = metadata_map[_token_ids[i]];
        }

        exts = new HeroMetaDataExt[][](_token_ids.length);
        for(uint256 i=0; i<_token_ids.length; i++) {
            exts[i] = getMetaExt(_token_ids[i]);
        }
    }

    function getMeta2(uint256 _token_id) external view returns (HeroMetaDataV2 memory meta, HeroMetaDataExt[] memory exts)
    {
        require(_exists(_token_id), "invalid token id");
        meta = metadata_map[_token_id];
        exts = getMetaExt(_token_id);
    }

    function getMetaExt(uint256 _token_id) public view returns (HeroMetaDataExt[] memory) {
        HeroMetaDataExt[] memory exts = new HeroMetaDataExt[](ext_keys.length);
        for(uint256 i=0; i<ext_keys.length; i++) {
            exts[i] = HeroMetaDataExt({
                key: ext_keys[i],
                val: metadata_ext_map[_token_id][ext_keys[i]]
            });
        }
        return exts;
    }

    function setMeta(uint256 _token_id, HeroMetaDataV2 calldata _meta, HeroMetaDataExt[] calldata _exts) external nonReentrant onlyWhiteList
    {
        require(_exists(_token_id), "invalid token id");

        metadata_map[_token_id] = _meta;
        for(uint256 i=0; i < _exts.length; i++) {
            require(existExtKey(_exts[i].key), 'nonexistence key');
            metadata_ext_map[_token_id][_exts[i].key] = _exts[i].val;
        }
        emit HeroChanged(ownerOf(_token_id), _token_id, _meta, _exts);
    }

    function burn(uint256 _token_id) external nonReentrant
    {
        require(ownerOf(_token_id) == msg.sender, "only the owner can burn");

        _burn(_token_id);
        delete metadata_map[_token_id];
    }

    function exists(uint256 _token_id) public view returns(bool)
    {
        return _exists(_token_id);
    }

    function mint(uint8 _mint_type, address _to, uint256 _token_id, HeroMetaDataV2 calldata _meta, HeroMetaDataExt[] calldata _exts) external nonReentrant onlyWhiteList
    {
        _safeMint(_to, _token_id);
        metadata_map[_token_id] = _meta;
        for(uint256 i=0; i < _exts.length; i++) {
            require(existExtKey(_exts[i].key), 'nonexistence key');
            metadata_ext_map[_token_id][_exts[i].key] = _exts[i].val;
        }
        emit HeroCreated(_mint_type, _to, _token_id, _meta, _exts);
    }

    function setBaseTokenURI(string calldata _base_token_uri, string calldata _suffix) external onlyOwner
    {
        base_token_uri = _base_token_uri;
        suffix = _suffix;
    }

    function setExtKeys(uint256[] memory _keys) external onlyOwner {
        for(uint256 i=0; i < _keys.length; i++) {
            require(_keys[i] > 0, 'key must be greater than 0');
        }
        ext_keys = _keys;
    }

    function setWhiteList(address _addr, bool _value) public onlyOwner {
        emit WhiteListChanged(_addr, whiteList[_addr], _value);
        whiteList[_addr] = _value;
    }
    
    function setWhiteLists(address[] calldata _addrs, bool[] calldata _values) external onlyOwner {
        require(_addrs.length == _values.length, 'GBB: INVALID_PARAM');
        for(uint i; i<_addrs.length; i++) {
            setWhiteList(_addrs[i], _values[i]);
        }
    }
}
