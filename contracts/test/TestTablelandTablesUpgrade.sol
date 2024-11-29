// SPDX-License-Identifier: MIT
pragma solidity >=0.8.10 <0.9.0;

import {ERC721AUpgradeable} from "erc721a-upgradeable/contracts/ERC721AUpgradeable.sol";
import {ERC721AQueryableUpgradeable} from "erc721a-upgradeable/contracts/extensions/ERC721AQueryableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {ITablelandTables} from "../interfaces/ITablelandTables.sol";
import {ITablelandController} from "../interfaces/ITablelandController.sol";
import {TablelandPolicy} from "../TablelandPolicy.sol";

contract TestTablelandTablesUpgrade is
    ITablelandTables,
    ERC721AUpgradeable,
    ERC721AQueryableUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    string internal _baseURIString;
    mapping(uint256 => address) internal _controllers;
    mapping(uint256 => bool) internal _locks;
    uint256 internal constant QUERY_MAX_SIZE = 35000;

    mapping(uint256 => address) private _dummyStorage;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory baseURI
    ) public initializerERC721A initializer {
        __ERC721A_init("Tableland Tables", "TABLE");
        __ERC721AQueryable_init();
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _baseURIString = baseURI;
    }

    function createTable(
        address owner,
        string calldata statement
    ) external payable whenNotPaused returns (uint256) {
        return _create(owner, statement);
    }

    function create(
        address owner,
        string calldata statement
    ) external payable override whenNotPaused returns (uint256) {
        return _create(owner, statement);
    }

    function create(
        address owner,
        string[] calldata statements
    ) external payable override whenNotPaused returns (uint256[] memory) {
        if (statements.length < 1) {
            revert Unauthorized();
        }

        uint256[] memory tableIds = new uint256[](statements.length);
        for (uint256 i = 0; i < statements.length; i++) {
            tableIds[i] = _create(owner, statements[i]);
        }

        return tableIds;
    }

    /**
     * @custom:depreciated
     */
    function runSQL(
        address caller,
        uint256 tableId,
        string calldata statement
    ) external payable whenNotPaused nonReentrant {
        _mutate(caller, tableId, statement);
    }

    function mutate(
        address caller,
        uint256 tableId,
        string calldata statement
    ) external payable override whenNotPaused nonReentrant {
        _mutate(caller, tableId, statement);
    }

    function mutate(
        address caller,
        ITablelandTables.Statement[] calldata statements
    ) external payable override whenNotPaused nonReentrant {
        for (uint256 i = 0; i < statements.length; i++) {
            _mutate(caller, statements[i].tableId, statements[i].statement);
        }
    }

    function _create(
        address owner,
        string calldata statement
    ) private returns (uint256 tableId) {
        tableId = _nextTokenId();
        _safeMint(owner, 1);

        emit CreateTable(owner, tableId, statement);

        return tableId;
    }

    function _mutate(
        address caller,
        uint256 tableId,
        string calldata statement
    ) private {
        if (!_exists(tableId) || caller != _msgSenderERC721A()) {
            revert Unauthorized();
        }

        uint256 querySize = bytes(statement).length;
        if (querySize > QUERY_MAX_SIZE) {
            revert MaxQuerySizeExceeded(querySize, QUERY_MAX_SIZE);
        }

        emit RunSQL(
            caller,
            ownerOf(tableId) == caller,
            tableId,
            statement,
            _getPolicy(caller, tableId)
        );
    }

    function _getPolicy(
        address caller,
        uint256 tableId
    ) private returns (TablelandPolicy memory) {
        address controller = _controllers[tableId];
        if (_isContract(controller)) {
            // Try {ITablelandController.getPolicy(address, uint256)}.
            try
                ITablelandController(controller).getPolicy{value: msg.value}(
                    caller,
                    tableId
                )
            returns (TablelandPolicy memory policy) {
                return policy;
            } catch Error(string memory reason) {
                // Controller reverted/required with a reason string. Bubble up the error.
                revert(reason);
            } catch (bytes memory err) {
                // We are here for one of two reasons:
                // 1. The controller does not implement {ITablelandController.getPolicy(address, uint256)}.
                // 2. The controller reverted w/o a reason string, e.g, a custom error, revert(), or require(condition).
                // We can't differentiate between reverting/requiring w/o a reason string and not implemented.
                // When a controller reverts/requires w/o a reason string it will be treated as not implemented,
                // i.e., we will try to call {ITablelandController.getPolicy(address)}.

                // Controller reverted with a custom error. Bubble it up.
                if (err.length > 0) {
                    // solhint-disable-next-line no-inline-assembly
                    assembly {
                        revert(add(32, err), mload(err))
                    }
                }
            }

            // If the controller reverted w/o a reason string, the following _could_ result in the caller
            // seeing a different error.
            // Try {ITablelandController.getPolicy(address)}.
            return
                ITablelandController(controller).getPolicy{value: msg.value}(
                    caller
                );
        }
        if (!(controller == address(0) || controller == caller)) {
            revert Unauthorized();
        }

        return
            TablelandPolicy({
                allowAlter: true,
                allowInsert: true,
                allowUpdate: true,
                allowDelete: true,
                whereClause: "",
                withCheck: "",
                updatableColumns: new string[](0)
            });
    }

    function _isContract(address account) private view returns (bool) {
        return account.code.length > 0;
    }

    function setController(
        address caller,
        uint256 tableId,
        address controller
    ) external override whenNotPaused {
        if (
            caller != ownerOf(tableId) ||
            caller != _msgSenderERC721A() ||
            _locks[tableId]
        ) {
            revert Unauthorized();
        }

        _controllers[tableId] = controller;

        emit SetController(tableId, controller);
    }

    function getController(
        uint256 tableId
    ) external view override returns (address) {
        return _controllers[tableId];
    }

    function lockController(
        address caller,
        uint256 tableId
    ) external override whenNotPaused {
        if (
            caller != ownerOf(tableId) ||
            caller != _msgSenderERC721A() ||
            _locks[tableId]
        ) {
            revert Unauthorized();
        }

        _locks[tableId] = true;
    }

    function setBaseURI(string memory baseURI) external override onlyOwner {
        _baseURIString = baseURI;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseURIString;
    }

    function pause() external override onlyOwner {
        _pause();
    }

    function unpause() external override onlyOwner {
        _unpause();
    }

    /**
     * @dev See {ERC721AUpgradeable-_startTokenId}.
     */
    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    /**
     * @dev See {ERC721AUpgradeable-_afterTokenTransfers}.
     */
    function _afterTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal override {
        super._afterTokenTransfers(from, to, startTokenId, quantity);
        if (from != address(0)) {
            // quantity is only > 1 after bulk minting when from == address(0)
            emit TransferTable(from, to, startTokenId);
        }
    }

    /**
     * @dev See {UUPSUpgradeable-_authorizeUpgrade}.
     */
    function _authorizeUpgrade(address) internal view override onlyOwner {} // solhint-disable no-empty-blocks
}
