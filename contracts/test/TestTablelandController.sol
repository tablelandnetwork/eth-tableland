// SPDX-License-Identifier: MIT
pragma solidity >=0.8.10 <0.9.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {TablelandController} from "../TablelandController.sol";
import {TablelandPolicy} from "../TablelandPolicy.sol";
import {Policies} from "../policies/Policies.sol";
import {ERC721EnumerablePolicies} from "../policies/ERC721EnumerablePolicies.sol";
import {ERC721AQueryablePolicies} from "../policies/ERC721AQueryablePolicies.sol";

contract TestTablelandController is TablelandController, Ownable {
    error InsufficientValue(uint256 receivedValue, uint256 requiredValue);

    uint256 public constant REQUIRED_VALUE = 1 ether;

    address private _foos;
    address private _bars;

    function getPolicy(
        address caller,
        uint256
    ) public payable override returns (TablelandPolicy memory) {
        // Enforce some ether and revert if insufficient
        if (msg.value < 1 ether) {
            revert InsufficientValue(msg.value, REQUIRED_VALUE);
        }

        // The following line is for coverage of a revert/require error
        require(msg.value == 1 ether, "too much ether!");

        string[] memory whereClauses = new string[](2);
        string[] memory withChecks = new string[](3);

        // Require one of FOO
        whereClauses[0] = ERC721EnumerablePolicies.getClauseForRequireOneOf(
            caller,
            _foos,
            "foo_id"
        );

        // Require one of BAR
        whereClauses[1] = ERC721AQueryablePolicies.getClauseForRequireOneOf(
            caller,
            _bars,
            "bar_id"
        );

        // Restrict updates to a single column
        string[] memory updatableColumns = new string[](1);
        updatableColumns[0] = "baz";

        // Include a check on the incoming data
        withChecks[0] = ""; // included to filter in Policies.joinClauses
        withChecks[1] = "baz > 0";
        withChecks[2] = ""; // included to filter in Policies.joinClauses

        // Return policy
        return
            TablelandPolicy({
                allowAlter: false,
                allowInsert: false,
                allowUpdate: true,
                allowDelete: false,
                whereClause: Policies.joinClauses(whereClauses),
                withCheck: Policies.joinClauses(withChecks),
                updatableColumns: updatableColumns
            });
    }

    function setFoos(address foos) external onlyOwner {
        _foos = foos;
    }

    function setBars(address bars) external onlyOwner {
        _bars = bars;
    }
}
