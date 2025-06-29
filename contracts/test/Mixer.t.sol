// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {Mixer} from "../src/Mixer.sol";
import {HonkVerifier} from "../src/Verifier.sol";
import {Test, console} from "forge-std/Test.sol";
import {IncrementalMerkleTree, Poseidon2} from "../src/IncrementalMerkleTree.sol";

contract MixerTest is Test {
    Mixer public mixer;
    HonkVerifier public verifier;
    Poseidon2 public hasher;

    address public recipient = makeAddr("recipient");

    function setUp() public {
        // deploy the verifier
        verifier = new HonkVerifier();
        // deploy the hasher contracts
        hasher = new Poseidon2();
        // deploy the mixer
        mixer = new Mixer(verifier, hasher, 20);
    }

    function testMakeDeposit() public {
        // create a commitment
        (bytes32 _commitment, , ) = _getCommitment();
        console.log("Commitment: ");
        console.logBytes32(_commitment);
        // make a deposit

        vm.expectEmit(true, false, false, true);
        emit Mixer.Deposit(_commitment, 0, block.timestamp);
        mixer.deposit{value: mixer.DENOMINATION()}(_commitment);
    }

    function testMakeWithdrawl() public {
        // create a commitment
        (
            bytes32 _commitment,
            bytes32 _nullifier,
            bytes32 _secret
        ) = _getCommitment();
        console.log("Commitment: ");
        console.logBytes32(_commitment);
        // make a deposit

        vm.expectEmit(true, false, false, true);
        emit Mixer.Deposit(_commitment, 0, block.timestamp);
        mixer.deposit{value: mixer.DENOMINATION()}(_commitment);

        // create a proof
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = _commitment;
        (bytes memory _proof, bytes32[] memory publicInputs) = _getProof(
            _nullifier,
            _secret,
            recipient,
            leaves
        );
        console.logBytes(_proof);
        assertTrue(verifier.verify(_proof, publicInputs));
        assertEq(recipient.balance, 0);
        assertEq(address(mixer).balance, mixer.DENOMINATION());
        mixer.withdraw(_proof, publicInputs[0], publicInputs[1], recipient);
        assertEq(recipient.balance, mixer.DENOMINATION());
        assertEq(address(mixer).balance, 0);
    }

    function _getProof(
        bytes32 _nullifier,
        bytes32 _secret,
        address _recipient,
        bytes32[] memory leaves
    ) internal returns (bytes memory proof, bytes32[] memory publicInputs) {
        // use ffi to run scripts in the CLI to create the proof
        string[] memory inputs = new string[](6 + leaves.length);
        inputs[0] = "npx";
        inputs[1] = "tsx";
        inputs[2] = "js-scripts/generateProof.ts";
        inputs[3] = vm.toString(_nullifier);
        inputs[4] = vm.toString(_secret);
        inputs[5] = vm.toString(bytes32(uint256(uint160(_recipient))));

        for (uint256 i = 0; i < leaves.length; i++) {
            inputs[6 + i] = vm.toString(leaves[i]);
        }
        bytes memory result = vm.ffi(inputs);
        (proof, publicInputs) = abi.decode(result, (bytes, bytes32[]));
    }

    function _getCommitment()
        public
        returns (bytes32 _commitment, bytes32 _nullifier, bytes32 _secret)
    {
        // use ffi to run scripts in the CLI to create the commitment
        string[] memory inputs = new string[](3);
        inputs[0] = "npx";
        inputs[1] = "tsx";
        inputs[2] = "js-scripts/generateCommitment.ts";
        bytes memory result = vm.ffi(inputs);
        (_commitment, _nullifier, _secret) = abi.decode(
            result,
            (bytes32, bytes32, bytes32)
        );
    }
}
