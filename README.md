# Provably Random Ruffle Contracts

## About 

This code is to create a proveably random smart contract lottery.

# What we want it to do?

1. Users can enter by paying for a ticket
    1. The ticket fees are going to a winner during the draw.
2. After X period of time, will automatically draw a winner. 
    1. And this will be done progamatically
3. Using Chainlink VRF & Chainlink Automation
    1. Chainlink VRF --> Randomness
    2. Chainlink Automation --> Time based trigger

## Tests 

1. Write some deploy scripts
2. Write our tests
    1. Work with a local chain
    2. Forked testnet
    3. Forked mainnet