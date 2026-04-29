// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IPriceOracle {
    function getPrice(address token,uint256 amount) external view returns (uint256 usdValue);
}