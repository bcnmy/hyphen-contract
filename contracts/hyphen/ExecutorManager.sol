// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./interfaces/IExecutorManager.sol";

contract ExecutorManager is IExecutorManager, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private executors;

    event ExecutorAdded(address executor, address owner);
    event ExecutorRemoved(address executor, address owner);

    // MODIFIERS
    modifier onlyExecutor() {
        require(getExecutorStatus(msg.sender), "You are not allowed to perform this operation");
        _;
    }

    function getExecutorStatus(address executor) public view override returns (bool status) {
        return executors.contains(executor);
    }

    function getAllExecutors() public view override returns (address[] memory) {
        address[] memory result = new address[](executors.length());
        for (uint256 i = 0; i < executors.length(); ) {
            result[i] = executors.at(i);
            unchecked {
                ++i;
            }
        }
        return result;
    }

    //Register new Executors
    function addExecutors(address[] calldata executorArray) external override onlyOwner {
        for (uint256 i = 0; i < executorArray.length; ) {
            addExecutor(executorArray[i]);
            unchecked {
                ++i;
            }
        }
    }

    // Register single executor
    function addExecutor(address executorAddress) public override onlyOwner {
        require(executorAddress != address(0), "executor address can not be 0");
        require(!getExecutorStatus(executorAddress), "Executor already registered");
        executors.add(executorAddress);
        emit ExecutorAdded(executorAddress, msg.sender);
    }

    //Remove registered Executors
    function removeExecutors(address[] calldata executorArray) external override onlyOwner {
        for (uint256 i = 0; i < executorArray.length; ) {
            removeExecutor(executorArray[i]);
            unchecked {
                ++i;
            }
        }
    }

    // Remove Register single executor
    function removeExecutor(address executorAddress) public override onlyOwner {
        require(getExecutorStatus(executorAddress), "Executor not registered");
        executors.remove(executorAddress);
        emit ExecutorRemoved(executorAddress, msg.sender);
    }
}
