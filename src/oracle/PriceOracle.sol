// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPriceOracle} from "../interfaces/IPriceOracle.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract PriceOracle is IPriceOracle {
    function getPrice(
        address token,
        uint256 amount
    ) external pure returns (uint256 usdValue) {
        require(amount > 0, "amount invaild");
        if (token == address(0)) {
            // 说明是ETH，那么先返回2318*amount
            return 2318 * amount * 10**18; // 假设每个单位的 ETH 价值 2318 美元
        } else {
            IERC20(token).totalSupply();
            // 其他代币，直接返回100*amount
            return 100 * amount * IERC20(token).decimals(); // 假设每个单位的 token 价值 100 美元
        }
    }
}
