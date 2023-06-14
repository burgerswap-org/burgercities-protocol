// SPDX-License-Identifier: MIT



pragma solidity ^0.8.0;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";


import "./Configable.sol";



contract NFTSwap is Configable, IERC721Receiver {

    using EnumerableSet for EnumerableSet.UintSet;

    uint public min_price = 0.01 ether;
    uint public max_price = 9999999 ether;

    struct Pool {
        address seller;         //seller
        address nftcontract;    //erc721 address
        uint token_id;          //erc721 tokenid
        address erc20;          //erc20 address
        uint price;             //price
        uint64 create_time;     //pub time
    }

    uint64 public publish_count = 0;
    uint16 public tx_fee = 50;         //permillage

    mapping(uint64 => Pool) public pools;
    EnumerableSet.UintSet all_created;
    mapping(address => EnumerableSet.UintSet) my_created;
    mapping(address => bool) public whitelist_contracts;
    mapping(address => bool) public whitelist_erc20;

    event Created(uint64 id, address seller, address nftcontract, uint token_id, address erc20, uint price, uint64 create_time);
    event Swapped(uint64 id, address buyer, address nftcontract, uint64 buy_time);
    event Canceled(uint64 id, address nftcontract);

    constructor()
    {
        owner = msg.sender;
    }

    function createErc721(address _nftcontract, uint _token_id, address _erc20, uint _price) external {
        require(whitelist_contracts[_nftcontract], "invalid nftcontract");
        require(whitelist_erc20[_erc20], "invalid erc20");
        require(_price >= min_price, "the value of price must >= min_price");
        require(_price <= max_price, "the value of price must <= max_price");
        // transfer tokenId of token0 to this contract
        IERC721(_nftcontract).safeTransferFrom(msg.sender, address(this), _token_id);

        uint64 id = ++publish_count;
        uint64 timestamp = uint64(block.timestamp);

        // creator pool
        Pool memory pool;
        pool.seller = msg.sender;
        pool.nftcontract = _nftcontract;
        pool.token_id = _token_id;
        pool.erc20 = _erc20;
        pool.price = _price;
        pool.create_time = timestamp;

        pools[id] = pool;

        my_created[msg.sender].add(id);
        all_created.add(id);
        emit Created(id, msg.sender, _nftcontract, _token_id, _erc20, _price, timestamp);
    }

    function swap(uint64 _id) external payable {
        Pool memory pool = pools[_id];

        require(pool.seller != address(0), "Invalid id");
        require(pool.seller != msg.sender, "creator can't swap the pool created by self");
        if (pool.erc20 == address(0)) {
            require(pool.price == msg.value, "invalid ETH amount");
        }

        uint fee = pool.price * uint(tx_fee) / 1000;
        uint after_fee = pool.price - fee;

        if (after_fee > 0) {
            if (pool.erc20 == address(0)) {
                payable(pool.seller).transfer(after_fee);
            } else {
                IERC20(pool.erc20).transferFrom(msg.sender, pool.seller, after_fee);
            }
        }

        if (fee > 0) {
            if (pool.erc20 == address(0)) {
            } else {
                IERC20(pool.erc20).transferFrom(msg.sender, address(this), fee);
            }
        }

        IERC721(pool.nftcontract).safeTransferFrom(address(this), msg.sender, pool.token_id);

        uint64 timestamp = uint64(block.timestamp);
        emit Swapped(_id, msg.sender, pool.nftcontract, timestamp);

        my_created[pool.seller].remove(_id);
        all_created.remove(_id);
        delete pools[_id];
    }

    function cancel(uint64 _id) external {
        Pool memory pool = pools[_id];

        require(pool.seller != address(0), "Invalid id");
        require(pool.seller == msg.sender, "creator has canceled this pool");

        IERC721(pool.nftcontract).safeTransferFrom(address(this), msg.sender, pool.token_id);

        emit Canceled(_id, pool.nftcontract);

        my_created[pool.seller].remove(_id);
        all_created.remove(_id);
        delete pools[_id];
    }

    function getSellerSupply(address _account) public view returns (uint32) {
        return uint32(my_created[_account].length());
    }

    function getSellerSupplyList(address _account, uint32 _begin, uint32 _count) public view returns (uint64[] memory, Pool[] memory) {
        uint32 length = getSellerSupply(_account);
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
    function addWhitelistNFT(address[] memory _whitelist) external onlyAdmin {
        for (uint i = 0; i < _whitelist.length; i++) {
            whitelist_contracts[_whitelist[i]] = true;
        }
    }

    function removeWhitelistNFT(address[] memory _whitelist) external onlyAdmin {
        for (uint i = 0; i < _whitelist.length; i++) {
            delete whitelist_contracts[_whitelist[i]];
        }
    }

    function addWhitelistErc20(address[] memory _whitelist) external onlyAdmin {
        for (uint i = 0; i < _whitelist.length; i++) {
            whitelist_erc20[_whitelist[i]] = true;
        }        
    }

    function removeWhitelistErc20(address[] memory _whitelist) external onlyAdmin {
        for (uint i = 0; i < _whitelist.length; i++) {
            delete whitelist_erc20[_whitelist[i]];
        }
    }

    function withdraw(address _to) external onlyAdmin
    {
        if (address(this).balance > 0) {
            payable(_to).transfer(address(this).balance);
        }
    }

    function withdrawErc20(address _to, address _erc20) external onlyAdmin
    {
        if (_erc20 == address(0)) {
            if (address(this).balance > 0) {
                payable(_to).transfer(address(this).balance);
            }
        } else {
            uint balance = IERC20(_erc20).balanceOf(address(this));
            if (balance > 0) {
                IERC20(_erc20).transfer(_to, balance);
            }                
        }
    }

    function balanceOfErc20(address _erc20) external view returns (uint)
    {
        if (_erc20 == address(0)) {
            return address(this).balance;
        } else {
            return IERC20(_erc20).balanceOf(address(this));
        }
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
}
