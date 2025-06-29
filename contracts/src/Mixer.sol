// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;
import {IncrementalMerkleTree, Poseidon2} from "./IncrementalMerkleTree.sol";
import {IVerifier} from "./Verifier.sol";

contract Mixer is IncrementalMerkleTree {
    mapping(bytes32 => bool) s_commitments;
    mapping(bytes32 => bool) s_nullifierHashes; // nullifier hashes to prevent double withdrawals
    uint256 public constant DENOMINATION = 0.001 ether; // fixed denomination for deposits
    IVerifier public immutable i_verifier; // Verifier contract to check zk-SNARK proofs

    // errors
    error Mixer__CommitmentAlreadyAdded(bytes32 commitment);
    error Mixer__DepositAmountNotCorrect(
        uint256 amountSent,
        uint256 expectedAmount
    );
    error Mixer__UnknownRoot(bytes32 root);
    error Mixer__NullifierAlreadyUsed(bytes32 nullifierHash);
    error Mixer__PaymentFailed(address recipient, uint256 amount);
    error Mixer__InvalidProof();
    // events
    event Deposit(
        bytes32 indexed commitment,
        uint32 indexed insertedIndex,
        uint256 timestamp
    );
    event Withdrawal(address indexed recipient, bytes32 indexed nullifierHash);

    constructor(
        IVerifier _verifier,
        Poseidon2 _hasher,
        uint32 _merkleTreeDepth
    ) IncrementalMerkleTree(_merkleTreeDepth, _hasher) {
        i_verifier = _verifier;
    }

    // deposit funds into the mixer
    function deposit(bytes32 _commitment) external payable {
        // check whether the commitment has been used so we can prevent double deposits
        if (s_commitments[_commitment]) {
            revert Mixer__CommitmentAlreadyAdded(_commitment);
        }
        // allow user to send ETH and make sure it is of the correct amount (denomination)
        if (msg.value != DENOMINATION) {
            revert Mixer__DepositAmountNotCorrect(msg.value, DENOMINATION);
        }
        // add the commitment to a data structure containing all commitments
        uint32 insertedIndex = _insert(_commitment);
        s_commitments[_commitment] = true;
        emit Deposit(_commitment, insertedIndex, block.timestamp);
    } 

    // allow you to withdraw funds from the mixer in a private way
    //@param _proof the proof that the user has the right to withdraw funds
    function withdraw(
        bytes memory _proof,
        bytes32 _root,
        bytes32 _nullfierHash,
        address _recipient
    ) external {
        // check that the root that was used in the proof matches the root on-chain
        if (!isKnownRoot(_root)) {
            revert Mixer__UnknownRoot(_root);
        }
        // check that the nullifier hash has not been used before
        if (s_nullifierHashes[_nullfierHash]) {
            revert Mixer__NullifierAlreadyUsed(_nullfierHash);
        }
        // check if the proof is valid by calling the verifier contract
        bytes32[] memory publicInputs = new bytes32[](3);
        publicInputs[0] = _root; // nullifier hash
        publicInputs[1] = _nullfierHash; // recipient address
        publicInputs[2] = bytes32(uint256(uint160(address(_recipient)))); // recipient address as bytes32
        if (!i_verifier.verify(_proof, publicInputs)) {
            revert("Invalid proof");
        }
        // check the nullifier to ensure the user has not already withdrawn
        s_nullifierHashes[_nullfierHash] = true; // mark the nullifier as used
        // send them the funds
        (bool success, ) = _recipient.call{value: DENOMINATION}("");
        if (!success) {
            revert Mixer__PaymentFailed(_recipient, DENOMINATION);
        }
        emit Withdrawal(_recipient, _nullfierHash);
    }
}
