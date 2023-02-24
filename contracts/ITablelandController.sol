// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./TablelandPolicy.sol";

/**
 * @dev Interface of a TablelandController compliant contract.
 *
 * This interface can be implemented to enabled advanced access control for a table.
 * Call {ITablelandTables-setController} with the address of your implementation.
 *
 * See {test/TestTablelandController} for an example of token-gating table write-access.
 */
interface ITablelandController {
    /**
     * @dev Returns a {TablelandPolicy} struct defining how a table can be accessed by `caller`.
     */
    function getPolicy(
        address caller,
        uint256 tableId
    ) external payable returns (TablelandPolicy memory);
}
