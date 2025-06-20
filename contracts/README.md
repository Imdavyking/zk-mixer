# ZK Mixer Project

- Deposit: users can deposit ETH into the mixer to break the connection between depositor and withdrawer.
- Withdraw: users will withdraw using a ZK proof (Noir - generated off-chain) of knowledge of their deposit
- We will only allow users to deposit a fixed amount of ETH (0.001 ETH)

## Proof
- calculate the commitment using the secret and nullifier
- we need to check that the commiment is present in the merkle tree
    - proposed root
    - merkle proof
- Check the nullifier matches the (public) nullifier hash

### Private inputs
- Secret
- Nullifier
- Merkle proof ()