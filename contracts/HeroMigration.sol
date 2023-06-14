// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./Common.sol";
import "./Configable.sol";
import "./lib/Signature.sol";

contract HeroMigration is ReentrancyGuard, Configable {

    using SafeCast for uint;

    address public SIGNER;
    IHero721 public hero721;
    IHero721V2 public hero721v2;

    IERC20 public burger20;

    uint private rand_seed;
    uint public migration_bonus = 2 ether;

    constructor(address _hero721, address _hero721v2, address _burger20, address _signer)
    {
        owner = msg.sender;
        hero721 = IHero721(_hero721);
        hero721v2 = IHero721V2(_hero721v2);
        burger20 = IERC20(_burger20);
        SIGNER = _signer;
        rand_seed = 0;
    }


    function batchMigration(uint32[] memory _token_ids, uint _seed, uint _expiry_time, bytes memory _signatures) external nonReentrant
    {
        require(_token_ids.length > 0, "_token_ids cannot be empty");
        require(verify(msg.sender, _seed, _expiry_time, _signatures), "this sign is not valid");
        require(_expiry_time > block.timestamp, "_seed expired");

        for (uint i = 0; i < _token_ids.length; i++) {
            _migration(_token_ids[i], _seed);
        }

        uint balance = _token_ids.length * migration_bonus;
        if (balance > 0) {
            burger20.transfer(msg.sender, balance);
        }
    }

    function _migration(uint32 _token_id, uint _seed) internal
    {
        require(hero721.ownerOf(_token_id) == msg.sender, "only onwer of");
        hero721.safeTransferFrom(msg.sender, address(this), _token_id);

        HeroMetaData memory meta = hero721.getMeta(_token_id);
        HeroMetaDataV2 memory meta_v2;

        meta_v2.opened = meta.opened;        //box or hero
        meta_v2.gen = meta.gen;          //generation
        meta_v2.summon_cd = meta.summon_cd;       //next summon time
        meta_v2.summon_cnt = meta.summon_cnt;       //current summon count
        meta_v2.maxsummon_cnt = meta.maxsummon_cnt;    //max summon count
        meta_v2.d = meta.d;      //Dominant gene
        meta_v2.r1 = meta.r1;     //Recessive gene 1
        meta_v2.r2 = meta.r2;     //Recessive gene 2
        meta_v2.r3 = meta.r3;     //Recessive gene 3
        meta_v2.p1 = meta.p1;    //parent 1
        meta_v2.p2 = meta.p2;    //parent 2
        meta_v2.morale = 0;

        if (meta_v2.opened) {
            meta_v2.morale = randMorale(meta_v2.d, _seed);
        }

        HeroMetaDataExt[] memory _exts;
        hero721v2.mint(3, msg.sender, _token_id, meta_v2, _exts);
    }

    //*****************************************************************************
    //* inner
    //*****************************************************************************
    function randMod(uint _seed) internal returns(uint) {
        uint base = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, rand_seed, _seed)));  
        unchecked {
            rand_seed += base;
        }     
        return base;
    }

    function verify(address _account, uint _seed, uint _expiry_time, bytes memory _signatures) public view returns (bool) {

        bytes32 message = keccak256(abi.encodePacked(_account, _seed, _expiry_time));
        bytes32 hash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
        address[] memory sign_list = Signature.recoverAddresses(hash, _signatures);
        return sign_list[0] == SIGNER;
    }

    function randMorale(uint8 d, uint _seed) internal returns (uint8) {
        
        uint rand = randMod(_seed);
        uint8 rate = uint8(rand % 41);

        if (d >= 1 && d <= 8) {
            return 30 + rate;
        } else if (d >= 9 && d <= 12) {
            return 35 + rate;
        } else if (d >= 13 && d <= 14) {
            return 40 + rate;
        } else if (d == 15) {
            return 45 + rate;
        } else {
            return 0;
        }
    }

    function onERC721Received(
        address /* _operator */,
        address /* _from */,
        uint256 /* _tokenId */,
        bytes calldata /* data */
    ) external view returns (bytes4) {
        require(msg.sender == address(hero721), 'only hero721 v1');
        return IERC721Receiver.onERC721Received.selector;
    }
    
    //*****************************************************************************
    //* manage
    //*****************************************************************************
    function withdraw(address _to) external onlyAdmin
    {
        if (address(this).balance > 0) {
            payable(_to).transfer(address(this).balance);
        }
    }

    function withdrawBurger(address _to) external onlyAdmin
    {
        uint balance = burger20.balanceOf(address(this));
        if (balance > 0) {
            burger20.transfer(_to, balance);
        }
    }

    function balanceOfBurger() external view returns (uint)
    {
        return burger20.balanceOf(address(this));
    }

    function setInternalAddress(address _hero721, address _hero721v2, address _burger20) external onlyDev
    {
        hero721 = IHero721(_hero721);
        hero721v2 = IHero721V2(_hero721v2);
        burger20 = IERC20(_burger20);     
    }

    function setMigrationBonus(uint _migration_bonus) external onlyAdmin
    {
        migration_bonus = _migration_bonus;
    }

    function setSigner(address _signer) external onlyDev
    {
        SIGNER = _signer;
    }

    function burnHeroV1(uint32[] calldata _token_ids) external onlyAdmin
    {
        for(uint i=0; i<_token_ids.length; i++) {
            hero721.burn(_token_ids[i]);
        }
    }

    function emergencyRecoveryHeroV1(uint32[] calldata _token_ids, address[] calldata _users) external onlyAdmin
    {
        require(_token_ids.length == _users.length, 'invalid param');
        for(uint i=0; i<_token_ids.length; i++) {
            hero721.transferFrom(address(this), _users[i], _token_ids[i]);
        }
    }

    function kill() external onlyOwner
    {
        uint balance = burger20.balanceOf(address(this));
        if (balance > 0) {
            burger20.transfer(owner, balance);
        }
        selfdestruct(payable(owner));
    }
}