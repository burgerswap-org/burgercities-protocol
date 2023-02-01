// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./lib/openzeppelin/contracts/utils/math/SafeCast.sol";
import "./lib/openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./lib/openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./Common.sol";
import "./Configable.sol";
import "./lib/Signature.sol";

contract HeroManage is IHeroManage, ReentrancyGuard, Configable {

    using SafeCast for uint;

    address public SIGNER;
    IHero721V2 public hero721;
    IERC20 public burger20;

    address public nftlease;

    uint private rand_seed;
    uint public summon_price = 1 ether;

    uint32 public cd = 43200;

    uint32 public mutation_rate1 = 20;
    uint32 public mutation_rate2 = 10;

    uint16 constant max_creation = 10000;
    uint32 public descendants_token_count = max_creation;

    event OpenBox(address owner, uint32 token_id);
    event Summon(address owner, uint price);

    constructor(address _hero721, address _burger20, address _signer)
    {
        owner = msg.sender;
        hero721 = IHero721V2(_hero721);
        burger20 = IERC20(_burger20);
        SIGNER = _signer;
        rand_seed = 0;
    }

    function calcSummonBurger(uint32 _token_id1, uint32 _token_id2) external view returns (uint)
    {
        HeroMetaDataV2 memory meta1 = hero721.getMeta(_token_id1);
        HeroMetaDataV2 memory meta2 = hero721.getMeta(_token_id2);

        return calcSummonBurgerInner(meta1) + calcSummonBurgerInner(meta2);
    }

    function openBox(uint32 _token_id, address _account, uint _seed, uint _expiry_time, bytes memory _signatures) external nonReentrant
    {
        require(verify(_account, _seed, _expiry_time, _signatures), "this sign is not valid");
        require(_expiry_time > block.timestamp, "_seed expired");
        require(_account == msg.sender, "only the account signatures can open");
        _openBox(_token_id, _seed);
    }

    function batchOpenBox(uint32[] memory _token_ids) external onlyAdmin nonReentrant {
        for (uint i = 0; i < _token_ids.length; i++) {
            _openBox(_token_ids[i], block.timestamp);
        }
    }

    function summon(uint32 _token_id1, uint32 _token_id2, address _account, uint _seed, uint _expiry_time, bytes memory _signatures) external nonReentrant
    {
        require(_token_id1 != _token_id2, "same token_id");

        require(hero721.ownerOf(_token_id1) == msg.sender, "only the owner can summon");
        require(hero721.ownerOf(_token_id2) == msg.sender, "only the owner can summon");
        require(verify(_account, _seed, _expiry_time, _signatures), "this sign is not valid");
        require(_expiry_time > block.timestamp, "_seed expired");
        require(_account == msg.sender, "only the account signatures can summon");

        HeroMetaDataV2 memory meta1 = hero721.getMeta(_token_id1);
        HeroMetaDataV2 memory meta2 = hero721.getMeta(_token_id2);

        makeNew(msg.sender, _token_id1, meta1, _token_id2, meta2, _seed);
    }

    function summonLease(address _account, uint32 _token_id1, uint32 _token_id2, uint _seed, uint _expiry_time, bytes memory _signatures) external nonReentrant
    {
        require(msg.sender == nftlease);
        require(_token_id1 != _token_id2, "same token_id");
        require(hero721.ownerOf(_token_id1) == _account, "only the owner can summon");
        require(verify(_account, _seed, _expiry_time, _signatures), "this sign is not valid");
        require(_expiry_time > block.timestamp, "_seed expired");
        
        HeroMetaDataV2 memory meta1 = hero721.getMeta(_token_id1);
        HeroMetaDataV2 memory meta2 = hero721.getMeta(_token_id2);

        makeNew(_account, _token_id1, meta1, _token_id2, meta2, _seed);
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

    function max(uint _a, uint _b) internal pure returns(uint) {
        if (_a > _b) {
            return _a;
        }

        return _b;
    }

    function min(uint _a, uint _b) internal pure returns(uint) {
        if (_a < _b) {
            return _a;
        }

        return _b;
    }

    function calcRemainSummonCnt(HeroMetaDataV2 memory _meta) internal pure returns (uint32)
    {
        if (_meta.gen == 0) {
            return 100;
        }

        return (_meta.maxsummon_cnt - _meta.summon_cnt);
    }

    function calcSummonBurgerInner(HeroMetaDataV2 memory _meta) internal view returns (uint)
    {
        uint summon_cnt = min(_meta.summon_cnt, 13);

        uint burger = (uint(_meta.gen) * 10 + 6 + summon_cnt * 2) * summon_price;
        return burger;
    }

    function mixDNA(HeroMetaDataV2 memory _meta1, HeroMetaDataV2 memory _meta2, uint _seed) internal returns (uint8, uint8, uint8, uint8)
    {
        uint8[4] memory newdna;
        uint8[4] memory dna1;
        uint8[4] memory dna2;

        dna1[0] = _meta1.d;
        dna1[1] = _meta1.r1;
        dna1[2] = _meta1.r2;
        dna1[3] = _meta1.r3;

        dna2[0] = _meta2.d;
        dna2[1] = _meta2.r1;
        dna2[2] = _meta2.r2;
        dna2[3] = _meta2.r3;

        uint rand = randMod(_seed);      
        uint rate;
        
        //dna1
        rate = rand % 100;
        rand = rand / 100;
        if (rate < 25) {
            uint8 tmp = dna1[3];
            dna1[3] = dna1[2];
            dna1[2] = tmp;
        }

        rate = rand % 100;
        rand = rand / 100;
        if (rate < 25) {
            uint8 tmp = dna1[2];
            dna1[2] = dna1[1];
            dna1[1] = tmp;
        }

        rate = rand % 100;
        rand = rand / 100;
        if (rate < 25) {
            uint8 tmp = dna1[1];
            dna1[1] = dna1[0];
            dna1[0] = tmp;
        }

        //dna2
        rate = rand % 100;
        rand = rand / 100;
        if (rate < 25) {
            uint8 tmp = dna2[3];
            dna2[3] = dna2[2];
            dna2[2] = tmp;
        }

        rate = rand % 100;
        rand = rand / 100;
        if (rate < 25) {
            uint8 tmp = dna2[2];
            dna2[2] = dna2[1];
            dna2[1] = tmp;
        }

        rate = rand % 100;
        rand = rand / 100;
        if (rate < 25) {
            uint8 tmp = dna2[1];
            dna2[1] = dna2[0];
            dna2[0] = tmp;
        }

        //make new dna
        uint32 p1_rate1 = (100 - mutation_rate1) / 2 + mutation_rate1;
        uint32 p1_rate2 = (100 - mutation_rate2) / 2 + mutation_rate2;

        rate = rand % 100;
        rand = rand / 100;
        if ((dna1[0] == 1 && dna2[0] == 2) || (dna1[0] == 2 && dna2[0] == 1)) {
            if (rate < mutation_rate1) {
                newdna[0] = 9;
            } else if (rate < p1_rate1) {
                newdna[0] = dna1[0];
            } else {
                newdna[0] = dna2[0];
            }
        } else if ((dna1[0] == 3 && dna2[0] == 4) || (dna1[0] == 4 && dna2[0] == 3)) {
            if (rate < mutation_rate1) {
                newdna[0] = 10;
            } else if (rate < p1_rate1) {
                newdna[0] = dna1[0];
            } else {
                newdna[0] = dna2[0];
            }
        } else if ((dna1[0] == 5 && dna2[0] == 6) || (dna1[0] == 6 && dna2[0] == 5)) {
            if (rate < mutation_rate1) {
                newdna[0] = 11;
            } else if (rate < p1_rate1) {
                newdna[0] = dna1[0];
            } else {
                newdna[0] = dna2[0];
            }
        } else if ((dna1[0] == 7 && dna2[0] == 8) || (dna1[0] == 8 && dna2[0] == 7)) {
            if (rate < mutation_rate1) {
                newdna[0] = 12;
            } else if (rate < p1_rate1) {
                newdna[0] = dna1[0];
            } else {
                newdna[0] = dna2[0];
            }
        } else if ((dna1[0] == 9 && dna2[0] == 10) || (dna1[0] == 10 && dna2[0] == 9)) {
            if (rate < mutation_rate1) {
                newdna[0] = 13;
            } else if (rate < p1_rate1) {
                newdna[0] = dna1[0];
            } else {
                newdna[0] = dna2[0];
            }
        } else if ((dna1[0] == 11 && dna2[0] == 12) || (dna1[0] == 12 && dna2[0] == 11)) {
            if (rate < mutation_rate1) {
                newdna[0] = 14;
            } else if (rate < p1_rate1) {
                newdna[0] = dna1[0];
            } else {
                newdna[0] = dna2[0];
            }
        } else if ((dna1[0] == 13 && dna2[0] == 14) || (dna1[0] == 14 && dna2[0] == 13)) {
            if (rate < mutation_rate2) {
                newdna[0] = 15;
            } else if (rate < p1_rate2) {
                newdna[0] = dna1[0];
            } else {
                newdna[0] = dna2[0];
            }
        } else {
            if (rate < 50) {
                newdna[0] = dna1[0];
            } else {
                newdna[0] = dna2[0];
            } 
        }

        rate = rand % 100;
        rand = rand / 100;
        if (rate < 50) {
            newdna[1] = dna1[1];
        } else {
            newdna[1] = dna2[1];
        }

        rate = rand % 100;
        rand = rand / 100;
        if (rate < 50) {
            newdna[2] = dna1[2];
        } else {
            newdna[2] = dna2[2];
        }

        rate = rand % 100;
        rand = rand / 100;
        if (rate < 50) {
            newdna[3] = dna1[3];
        } else {
            newdna[3] = dna2[3];
        }

        return (newdna[0], newdna[1], newdna[2], newdna[3]);
    }

    function makeNew(address _to, uint32 _token_id1, HeroMetaDataV2 memory _meta1, uint32 _token_id2, HeroMetaDataV2 memory _meta2, uint _seed) internal
    {
        uint64 curtime = block.timestamp.toUint64();
        require(_meta1.opened, "token1 not open");
        require(_meta2.opened, "token2 not open");
        require(_meta1.summon_cd < curtime, "token1 cd");
        require(_meta2.summon_cd < curtime, "token2 cd");

        require(_meta1.p1 != _token_id2, "token1 p1 == token_id2");
        require(_meta1.p2 != _token_id2, "token1 p2 == token_id2");
        require(_meta2.p1 != _token_id1, "token2 p1 == token_id1");
        require(_meta2.p2 != _token_id1, "token2 p2 == token_id1");

        //calc summon num
        uint32 remainsummon1 = calcRemainSummonCnt(_meta1);
        uint32 remainsummon2 = calcRemainSummonCnt(_meta2);

        require(remainsummon1 > 0, "token1 cnt");
        require(remainsummon2 > 0, "token2 cnt");

        //calc burger
        uint sum_burger = calcSummonBurgerInner(_meta1) + calcSummonBurgerInner(_meta2);
        if (sum_burger > 0) {
            burger20.transferFrom(_to, address(this), sum_burger);
            emit Summon(_to, sum_burger);
        }

        //do summon logic
        HeroMetaDataV2 memory newmeta;
        //opened
        newmeta.opened = true;
        //gen
        newmeta.gen = uint8(max(_meta1.gen, _meta2.gen) + 1);
        //summon dna
        (newmeta.d, newmeta.r1, newmeta.r2, newmeta.r3) = mixDNA(_meta1, _meta2, _seed);
        //summon_cd
        newmeta.summon_cd = (uint(curtime) + 6 * uint(cd)).toUint64();
        //summon_cnt
        newmeta.summon_cnt = 0;
        //maxsummon_cnt
        if (newmeta.gen >= 11) {
            newmeta.maxsummon_cnt = 0;
        } else {
            uint maxsummon_cnt1 = 11 - newmeta.gen;
            uint maxsummon_cnt2;
            if (newmeta.d <= 8) {
                maxsummon_cnt2 = 10;
            } else if (newmeta.d <= 12) {
                maxsummon_cnt2 = 5;
            } else if (newmeta.d <= 14) {
                maxsummon_cnt2 = 3;
            } else {
                maxsummon_cnt2 = 1;
            }

            uint min1 = min(maxsummon_cnt1, maxsummon_cnt2);
            uint min2 = min(remainsummon1, remainsummon2) - 1;

            newmeta.maxsummon_cnt = uint8(min(min1, min2));
        }
        //p1
        newmeta.p1 = _token_id1;
        //p2
        newmeta.p2 = _token_id2;

        newmeta.morale = randMorale(newmeta.d, _seed);

        HeroMetaDataExt[] memory _exts;
        
        uint new_token_id = ++descendants_token_count;
        require(new_token_id < type(uint32).max, 'new_token_id overflow');
        hero721.mint(2, _to, new_token_id, newmeta, _exts);


        //change token1
        if (_meta1.summon_cnt < 100) {
            _meta1.summon_cnt += 1;            
        }

        uint summon_cnt1 = min(_meta1.summon_cnt, 13);

        _meta1.summon_cd = (uint(curtime) + (uint(_meta1.gen) + summon_cnt1) * uint(cd) + uint(cd)).toUint64();
        hero721.setMeta(_token_id1, _meta1, _exts);

        //change token2
        if (_meta2.summon_cnt < 100) {
            _meta2.summon_cnt += 1;            
        }

        uint summon_cnt2 = min(_meta2.summon_cnt, 13);

        _meta2.summon_cd = (uint(curtime) + (uint(_meta2.gen) + summon_cnt2) * uint(cd) + uint(cd)).toUint64();
        hero721.setMeta(_token_id2, _meta2, _exts);
    }

    function _openBox(uint32 _token_id, uint _seed) internal
    {
        require(hero721.ownerOf(_token_id) == msg.sender, "only the owner can open box");

        HeroMetaDataV2 memory meta = hero721.getMeta(_token_id);
        require(!meta.opened, "box opened");

        meta.opened = true;
        meta.gen = 0;

        uint cdtime = block.timestamp + 2 * uint(cd);
        meta.summon_cd = cdtime.toUint64();

        meta.summon_cnt = 0;
        meta.maxsummon_cnt = 0;

        uint rand = randMod(_seed);
        uint8 rate;

        rate = uint8(rand % 8);
        rand = rand / 8;
        meta.d = uint8(rate + 1);

        rate = uint8(rand % 8);
        rand = rand / 8;
        meta.r1 = uint8(rate + 1);

        rate = uint8(rand % 8);
        rand = rand / 8;
        meta.r2 = uint8(rate + 1);

        rate = uint8(rand % 8);
        rand = rand / 8;
        meta.r3 = uint8(rate + 1);

        meta.p1 = 0;
        meta.p2 = 0;

        // meta.morale = randMorale(meta.d, _seed);

        HeroMetaDataExt[] memory _exts;

        hero721.setMeta(_token_id, meta, _exts);
        emit OpenBox(msg.sender, _token_id);
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

    function verify(address _account, uint _seed, uint _expiry_time, bytes memory _signatures) public view returns (bool) {

        bytes32 message = keccak256(abi.encodePacked(_account, _seed, _expiry_time));
        bytes32 hash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
        address[] memory sign_list = Signature.recoverAddresses(hash, _signatures);
        return sign_list[0] == SIGNER;
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

    function setSummonPrice(uint _price) external onlyAdmin
    {
        require(_price > 0, "summon price should > 0");

        summon_price = _price;
    }

    function setSummonCD(uint32 _cd) external onlyAdmin
    {
        require(_cd > 0, "summon cd should > 0");

        cd = _cd;
    }

    function setMutationRate(uint32 _mutation_rate1, uint32 _mutation_rate2) external onlyAdmin
    {
        require(_mutation_rate1 <= 100, "_mutation_rate1 should <= 100");
        require(_mutation_rate2 <= 100, "_mutation_rate2 should <= 100");

        require(_mutation_rate1 % 2 == 0, "_mutation_rate1 must be an even number");
        require(_mutation_rate2 % 2 == 0, "_mutation_rate2 must be an even number");

        mutation_rate1 = _mutation_rate1;
        mutation_rate2 = _mutation_rate2;
    }

    function setHero721(address _hero721) external onlyDev
    {
        require(_hero721 != address(0), "address should not 0");
        hero721 = IHero721V2(_hero721);
    }

    function setBurger20(address _burger20) external onlyDev
    {
        require(_burger20 != address(0), "address should not 0");
        burger20 = IERC20(_burger20);
    }

    function setNFTLease(address _nftlease) external onlyDev
    {
        require(_nftlease != address(0), "address should not 0");
        nftlease = _nftlease;
    }

    function setSigner(address _signer) external onlyAdmin
    {
        SIGNER = _signer;
    }

    function setDescendantsTokenCount(uint32 _token_count) external onlyDev
    {
        require(_token_count > max_creation, "must be greater than max creation");
        descendants_token_count = _token_count;
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