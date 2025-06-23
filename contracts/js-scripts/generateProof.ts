import { Barretenberg, Fr, UltraHonkBackend } from "@aztec/bb.js";
import { ethers } from "ethers";
import { Noir } from "@noir-lang/noir_js";
import fs from "fs";
import path from "path";
import { merkleTree } from "./merkleTree.js";

const circuit = JSON.parse(
  fs.readFileSync(
    path.resolve(__dirname, "../../circuits/target/circuits.json"),
    "utf8"
  )
);

export default async function generateProof(): Promise<string> {
  const inputs = process.argv.slice(2);
  const noir = new Noir(circuit);
  const honk = new UltraHonkBackend(circuit.bytecode, {
    threads: 1,
  });
  const bb = await Barretenberg.new();
  const nullifier = Fr.fromString(inputs[0]);
  const secret = Fr.fromString(inputs[1]);
  const recipient = Fr.fromString(inputs[2]);

  const nullfierHash = await bb.poseidon2Hash([nullifier]);
  const commitment = await bb.poseidon2Hash([nullifier, secret]);

  const leaves = inputs.slice(3);
  const tree = await merkleTree(leaves);
  const merkleProof = tree.proof(tree.getIndex(commitment.toString()));

  const input = {
    // public inputs
    root: merkleProof.root.toString(),
    nullfier_hash: nullfierHash.toString(),
    recipient: recipient.toString(),
    // private inputs
    secret: secret.toString(),
    nullifier: nullifier.toString(),
    merkle_proof: merkleProof.pathElements.map((el) => el.toString()),
    is_even: merkleProof.pathIndices.map((el) => el % 2 === 0),
  };
  const { witness } = await noir.execute(input);
  const { proof, publicInputs } = await honk.generateProof(witness, {
    keccak: true,
  });
  const result = ethers.AbiCoder.defaultAbiCoder().encode(
    ["bytes", "bytes32["],
    [proof, publicInputs]
  );
  return result;
}

(async () => {
  const proof = await generateProof();
  process.stdout.write(proof);
  process.exit(0);
})().catch((error) => {
  console.error("Error generating commitment:", error);
  process.exit(1);
});
