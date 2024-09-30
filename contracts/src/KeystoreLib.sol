// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {IRecordController} from "./IRecordController.sol";

/// @dev The preimages of a Keyspace record value.
struct RecordValuePreimages {
    /// @dev The controller address, responsible for authorizing the update.
    address controller;
    /// @dev The current storage hash commited in the Keyspace record.
    bytes32 storageHash;
}

library KeystoreLib {
    ////////////////////////////////////////////////////////////////////////////////////////////////////
    //                                              EVENTS                                            //
    ////////////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Emitted when a Keyspace record is updated.
    ///
    /// @param id The ID of the Keyspace record updated.
    /// @param previousValue The previous Keyspace record value.
    /// @param newValue The new Keyspace record value.
    event RecordSet(bytes32 id, bytes32 previousValue, bytes32 newValue);

    ////////////////////////////////////////////////////////////////////////////////////////////////////
    //                                              ERRORS                                            //
    ////////////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Thrown when the provided `currentValue` and `currentValuePreimages` do not match.
    ///
    /// @param currentValue The Keyspace record current value.
    /// @param currentValueFromPreimages The Keyspace record current value recomputed from the preimages.
    error InvalidCurrentValuePreimages(bytes32 currentValue, bytes32 currentValueFromPreimages);

    /// @notice Thrown the Keyspace record update authorization fails.
    error Unhauthorized();

    ////////////////////////////////////////////////////////////////////////////////////////////////////
    //                                        INTERNAL FUNCTIONS                                      //
    ////////////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Perfoms an authorized update of a Keyspace record.
    ///
    /// @param records The Keyspace records storage pointer.
    /// @param id The ID of the Keyspace record to update.
    /// @param currentValue The Keyspace record current value.
    /// @param currentValuePreimages The Keyspace record current value preimages.
    /// @param newValue The Keyspace record new value.
    /// @param proof A proof provided to the `controller` to authorize the update.
    function set(
        mapping(bytes32 id => bytes32 value) storage records,
        bytes32 id,
        bytes32 currentValue,
        RecordValuePreimages calldata currentValuePreimages,
        bytes32 newValue,
        bytes calldata proof
    ) internal {
        // Recompute the Keyspace record current value from the provided preimages and ensure it maches with the
        // given `currentValue` parameter.
        bytes32 currentValueFromPreimages =
            keccak256(abi.encodePacked(currentValuePreimages.controller, currentValuePreimages.storageHash));
        if (currentValueFromPreimages != currentValue) {
            revert InvalidCurrentValuePreimages({
                currentValue: currentValue,
                currentValueFromPreimages: currentValueFromPreimages
            });
        }

        // TODO: here shouldn't we rather pass in the `storageHash` directly instead of the `currentValue`?
        bool authorized = IRecordController(currentValuePreimages.controller).authorize({
            id: id,
            currentValue: currentValue,
            newValue: newValue,
            proof: proof
        });

        if (!authorized) {
            revert Unhauthorized();
        }

        // TODO: We could require data availability here for both the new storageHash preimage and the newValue
        //       preimage. They could either be stored onchain or emitted as events.

        records[id] = newValue;
        emit RecordSet({id: id, previousValue: currentValue, newValue: newValue});
    }
}
