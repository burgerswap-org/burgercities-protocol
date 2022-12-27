// SPDX-License-Identifier: MIT



pragma solidity ^0.8.0;


import "./lib/openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./lib/openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./lib/openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./lib/openzeppelin/contracts/utils/structs/EnumerableSet.sol";


import "./Common.sol";
import "./Configable.sol";


contract NFTLease is Configable, IERC721Receiver {

    using EnumerableSet for EnumerableSet.UintSet;

    IERC20 public burger20;
    IHeroManage public heromanage;
    IHero721 public hero721;

    uint public min_price = 0.01 ether;
    uint public max_price = 9999999 ether;

    struct Pool {
        address owner;          //owner
        uint32 token_id;        //erc721 tokenid
        uint price;             //price
        uint64 create_time;     //pub time
    }

    uint64 public publish_count = 0;
    uint16 public tx_fee = 50;         //permillage

    mapping(uint64 => Pool) public pools;
    EnumerableSet.UintSet all_created;
    mapping(address => EnumerableSet.UintSet) my_created;

    event Created(uint64 id, address owner, uint32 token_id, uint price, uint64 create_time);
    event Leased(uint64 id, address lessee, uint64 lessee_time);
    event Canceled(uint64 id);

    constructor(address _burger20, address _heromanage, address _hero721)
    {
        owner = msg.sender;
        burger20 = IERC20(_burger20);
        heromanage = IHeroManage(_heromanage);  
        hero721 = IHero721(_hero721);
    }

    function createErc721(uint32 _token_id, uint _price) external {
        require(_price >= min_price, "the value of price must >= min_price");
        require(_price <= max_price, "the value of price must <= max_price");

        HeroMetaData memory meta = hero721.getMeta(_token_id);
        require(meta.opened, "token not open");
        if (meta.gen > 0) {
            require(meta.maxsummon_cnt > meta.summon_cnt, "remaining summon count must > 0");
        }

        hero721.safeTransferFrom(msg.sender, address(this), _token_id);

        uint64 id = ++publish_count;
        uint64 timestamp = uint64(block.timestamp);

        // creator pool
        Pool memory pool;
        pool.owner = msg.sender;
        pool.token_id = _token_id;
        pool.price = _price;
        pool.create_time = timestamp;

        pools[id] = pool;

        my_created[msg.sender].add(id);
        all_created.add(id);
        emit Created(id, msg.sender, _token_id, _price, timestamp);
    }

    function leaseForSummon(uint64 _id, uint32 my_token_id, uint _seed, uint _expiry_time, bytes memory _signatures) external {
        Pool memory pool = pools[_id];

        require(pool.owner != address(0), "Invalid id");
        require(pool.owner != msg.sender, "creator can't lease the pool created by self");

        uint fee = pool.price * uint(tx_fee) / 1000;
        uint after_fee = pool.price - fee;

        if (after_fee > 0) {
            burger20.transferFrom(msg.sender, pool.owner, after_fee);
        }

        if (fee > 0) {
            burger20.transferFrom(msg.sender, address(this), fee);
        }

        hero721.safeTransferFrom(address(this), pool.owner, pool.token_id);

        uint64 timestamp = uint64(block.timestamp);
        emit Leased(_id, msg.sender, timestamp);

        heromanage.summonLease(msg.sender, my_token_id, pool.token_id, _seed, _expiry_time, _signatures);

        my_created[pool.owner].remove(_id);
        all_created.remove(_id);
        delete pools[_id];
    }

    function cancel(uint64 _id) external {
        Pool memory pool = pools[_id];

        require(pool.owner != address(0), "Invalid id");
        require(pool.owner == msg.sender, "creator has canceled this pool");

        hero721.safeTransferFrom(address(this), pool.owner, pool.token_id);

        emit Canceled(_id);

        my_created[pool.owner].remove(_id);
        all_created.remove(_id);
        delete pools[_id];
    }

    function getOwnerSupply(address _account) public view returns (uint32) {
        return uint32(my_created[_account].length());
    }

    function getOwnerSupplyList(address _account, uint32 _begin, uint32 _count) public view returns (uint64[] memory, Pool[] memory) {
        uint32 length = getOwnerSupply(_account);
        require(length > _begin, "Invalid begin");

        uint32 ret_cnt = length - _begin;
        if (ret_cnt > _count) {
            ret_cnt = _count;
        }

        uint64[] memory ret_ids = new uint64[](ret_cnt);
        Pool[] memory ret_pool = new Pool[](ret_cnt);
        for (uint256 i = 0; i < ret_cnt; ++i) {
            uint64 id = uint64(my_created[_account].at(_begin + i));
            ret_ids[i] = id;
            ret_pool[i] = pools[id];
        }
        return (ret_ids, ret_pool);
    }

    function getTotalSupply() public view returns (uint32) {
        return uint32(all_created.length());
    }

    function getTotalSupplyList(uint32 _begin, uint32 _count) public view returns (uint64[] memory, Pool[] memory) {
        uint32 length = getTotalSupply();
        require(length > _begin, "Invalid begin");

        uint32 ret_cnt = length - _begin;
        if (ret_cnt > _count) {
            ret_cnt = _count;
        }

        uint64[] memory ret_ids = new uint64[](ret_cnt);
        Pool[] memory ret_pool = new Pool[](ret_cnt);
        for (uint256 i = 0; i < ret_cnt; ++i) {
            uint64 id = uint64(all_created.at(_begin + i));
            ret_ids[i] = id;
            ret_pool[i] = pools[id];
        }
        return (ret_ids, ret_pool);
    }

    function onERC721Received(address, address, uint, bytes calldata) external override pure returns (bytes4) {
        return this.onERC721Received.selector;
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

    function setFee(uint16 _tx_fee) external onlyAdmin
    {
        require(_tx_fee < 1000, "the value of fee must < 1000");

        tx_fee = _tx_fee;
    }

    function setMinMaxPrice(uint _min_price, uint _max_price) external onlyAdmin
    {
        require(_min_price < _max_price, "min_price must < max_price");
        min_price = _min_price;
        max_price = _max_price;
    }

    function setBurger20(address _burger20) external onlyDev
    {
        require(_burger20 != address(0), "address should not 0");
        burger20 = IERC20(_burger20);
    }

    function setHeroManage(address _heromanage) external onlyDev
    {
        require(_heromanage != address(0), "_heromanage address should not 0");
    
        heromanage = IHeroManage(_heromanage);  
    }

    function setHero721(address _hero721) external onlyDev
    {
        require(_hero721 != address(0), "_hero721 address should not 0");

        require(getTotalSupply() == 0, "total supply must == 0");
    
        hero721 = IHero721(_hero721);
    }
}
