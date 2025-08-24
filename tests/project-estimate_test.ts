import { 
  Clarinet,
  Tx,
  Chain,
  Account,
  types 
} from 'https://deno.land/x/clarinet@v1.5.4/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

Clarinet.test({
  name: "project-estimate: Can register estimation type",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const block = chain.mineBlock([
      Tx.contractCall('project-estimate', 'register-estimate-type', [
        types.ascii('software-dev'),
        types.utf8('Software Development Project Estimation')
      ], deployer.address)
    ]);

    block.receipts[0].result.expectOk();
  }
});

Clarinet.test({
  name: "project-estimate: Can create project estimate",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const block1 = chain.mineBlock([
      Tx.contractCall('project-estimate', 'register-estimate-type', [
        types.ascii('software-dev'),
        types.utf8('Software Development Project Estimation')
      ], deployer.address)
    ]);

    const block2 = chain.mineBlock([
      Tx.contractCall('project-estimate', 'create-project-estimate', [
        types.utf8('Web Platform Development'),
        types.ascii('software-dev'),
        types.uint(50000),
        types.uint(100),
        types.list([
          types.utf8('Frontend Developer'),
          types.utf8('Backend Developer')
        ]),
        types.uint(3)
      ], deployer.address)
    ]);

    block2.receipts[0].result.expectOk();
  }
});

Clarinet.test({
  name: "project-estimate: Can validate project estimate",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const validator = accounts.get('wallet_1')!;

    const block1 = chain.mineBlock([
      Tx.contractCall('project-estimate', 'register-estimate-type', [
        types.ascii('software-dev'),
        types.utf8('Software Development Project Estimation')
      ], deployer.address)
    ]);

    const block2 = chain.mineBlock([
      Tx.contractCall('project-estimate', 'create-project-estimate', [
        types.utf8('Web Platform Development'),
        types.ascii('software-dev'),
        types.uint(50000),
        types.uint(100),
        types.list([
          types.utf8('Frontend Developer'),
          types.utf8('Backend Developer')
        ]),
        types.uint(3)
      ], deployer.address)
    ]);

    const estimateId = block2.receipts[0].result.expectOk();

    const block3 = chain.mineBlock([
      Tx.contractCall('project-estimate', 'validate-project-estimate', [
        estimateId,
        types.bool(true),
        types.utf8('Looks good, budget seems reasonable')
      ], deployer.address)
    ]);

    block3.receipts[0].result.expectOk();
  }
});