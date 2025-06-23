import { Barretenberg, Fr } from "@aztec/bb.js";
import { ethers } from "ethers";

export default async function generateCommitment(): Promise<string> {
  const bb = await Barretenberg.new();
  const secret = Fr.random();
  const nullifier = Fr.random();
  const commitment = await bb.poseidon2Hash([nullifier, secret]);
  const result = ethers.AbiCoder.defaultAbiCoder().encode(
    ["bytes32", "bytes32", "bytes32"],
    [commitment.toBuffer(), nullifier.toBuffer(), secret.toBuffer()]
  );
  return result;
}

(async () => {
  const commitment = await generateCommitment();
  process.stdout.write(commitment);
  process.exit(0);
})().catch((error) => {
  console.error("Error generating commitment:", error);
  process.exit(1);
});
