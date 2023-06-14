// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRewardAgent {
    event SendERC20Reward(address indexed receiver, address token, uint256 amount, uint256 orderId);
    event SendERC721Reward(address indexed receiver, address nft, uint256 tokenId, uint256 orderId);
    event SendERC1155Reward(address indexed receiver, address nft, uint256 tokenId, uint256 amount, uint256 orderId);

    function signer() external view returns(address);

    function rewardERC20(
        address to,
        address token, 
        uint256 amount,
        uint64 orderId,
        bytes memory signature
    ) external returns(bool);

    function rewardERC721(
        address to,
        address nft, 
        uint256 tokenId,
        uint64 orderId,
        bytes memory signature
    ) external returns(bool);

    function rewardERC1155(
        address to,
        address token,
        uint256 tokenId,
        uint256 amount,
        uint64 orderId,
        bytes memory signature
    ) external returns(bool);
}