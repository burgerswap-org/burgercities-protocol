// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./lib/openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./lib/openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "./lib/openzeppelin/contracts/token/ERC1155/IERC1155.sol";


//Hero data structure
struct HeroMetaData {
    bool opened;        //box or hero
    uint8 gen;          //generation

    uint64 summon_cd;       //next summon time
    uint8 summon_cnt;       //current summon count
    uint8 maxsummon_cnt;    //max summon count
    uint8 d;      //Dominant gene
    uint8 r1;     //Recessive gene 1
    uint8 r2;     //Recessive gene 2
    uint8 r3;     //Recessive gene 3
    uint32 p1;    //parent 1
    uint32 p2;    //parent 2
}

//Hero data structure
struct HeroMetaDataV2 {
    bool opened;        //box or hero
    uint8 gen;          //generation

    uint64 summon_cd;       //next summon time
    uint8 summon_cnt;       //current summon count
    uint8 maxsummon_cnt;    //max summon count
    uint8 d;      //Dominant gene
    uint8 r1;     //Recessive gene 1
    uint8 r2;     //Recessive gene 2
    uint8 r3;     //Recessive gene 3
    uint32 p1;    //parent 1
    uint32 p2;    //parent 2
    uint8 morale;      //morale
}

struct HeroMetaDataExt {
    uint256 key;
    uint256 val;
}


interface IHero721 is IERC721, IERC721Enumerable {
    function getMeta(uint32 token_id) external view returns (HeroMetaData memory);
    function setMeta(uint32 token_id, HeroMetaData calldata meta) external;
    function burn(uint32 token_id) external;
    function exists(uint32 token_id) external view returns (bool);
    function createCreationTo(address to, HeroMetaData calldata meta) external;
    function createDescendantsTo(address to, HeroMetaData calldata meta) external;
    function calcCreationLimit() external view returns (uint16);
}

interface IHero721V2 is IERC721, IERC721Enumerable {
    function getMeta(uint256 token_id) external view returns (HeroMetaDataV2 memory);
    function getMeta2(uint256 _token_id) external view returns (HeroMetaDataV2 memory meta, HeroMetaDataExt[] memory exts);
    function getMetas2(uint256[] memory _token_ids) external view returns (uint256[] memory token_ids, HeroMetaDataV2[] memory metas, HeroMetaDataExt[][] memory exts);
    function setMeta(uint256 _token_id, HeroMetaDataV2 calldata _meta, HeroMetaDataExt[] calldata _exts) external;
    function burn(uint256 token_id) external;
    function mint(uint8 _mint_type, address _to, uint256 _token_id, HeroMetaDataV2 calldata _meta, HeroMetaDataExt[] calldata _exts) external;
    function exists(uint256 token_id) external view returns (bool);
    function getExtKeys() external view returns (uint256[] memory);
    function existExtKey(uint256 _key) external view returns (bool);

}

interface IClothing721 {
    function manageMintTo(address to, uint32 clothes_id) external;
}

interface IHeroManage {
    function summonLease(address _account, uint32 _token_id1, uint32 _token_id2, uint _seed, uint _expiry_time, bytes memory _signatures) external;
}

