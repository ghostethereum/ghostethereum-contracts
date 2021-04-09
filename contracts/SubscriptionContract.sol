// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

contract SubscriptionContract {
  address public serviceAddress = msg.sender;
  bool public halted = false;

  struct Subscription {
    bytes id; // bytes concatenation of addresses of owner, subscriber, and token
    address ownerAddress;
    address subscriberAddress;
    address tokenAddress; // subscription denominated token
    uint lastSettlementTime;
    uint value; // subscription value
    uint interval; // subscription interval in seconds

    // non-state variables
    uint ownerSubscriptionIndex;
    uint subscriberSubscriptionIndex;
    uint index;
    bool exists;
  }

  struct Owner {
    bytes[] subscriptionIDs;
    uint index;
    bool exists;
  }

  struct Subscriber {
    bytes[] subscriptionIDs;
    uint index;
    bool exists;
  }

  mapping (address => Owner) public owners;
  mapping (address => Subscriber) public subscribers;
  mapping (bytes => Subscription) public subscriptions;

  address[] public ownerIndices;
  address[] public subscriberIndices;
  bytes[] public subscriptionIndices;

  modifier restricted() {
    require(
      msg.sender == serviceAddress,
      "This function is restricted to the contract's service address"
    );
    _;
  }

  modifier notHalt() {
    require(
      !halted,
      "This function is not permitted when contract is halted"
    );
    _;
  }

  function halt() public restricted {
    halted = true;
  }

  function unhalt() public restricted {
    halted = false;
  }

  function getSubscriptionID(
    address ownerAddress,
    address subscriberAddress,
    address tokenAddress
  ) pure external returns (bytes memory) {
    bytes memory result = new bytes(96);
    assembly {
      mstore(add(result, 32), ownerAddress)
      mstore(add(result, 64), subscriberAddress)
      mstore(add(result, 96), tokenAddress)
    }
    return result;
  }

  function addSubscription(
    address ownerAddress,
    address tokenAddress,
    uint value,
    uint interval
  ) public notHalt returns (Subscription memory) {
    address subscriberAddress = msg.sender;
    bytes memory subscriptionID = this.getSubscriptionID(ownerAddress, subscriberAddress, tokenAddress);

    // Assert that subscription does not exist
    require(subscriptions[subscriptionID].exists != true);
    require(value > 0);
    require(interval > 0);

    if (owners[ownerAddress].exists == true) {
      owners[ownerAddress].subscriptionIDs.push(subscriptionID);
    } else {
      ownerIndices.push(ownerAddress);
      bytes[] memory emptySubIDs;
      owners[ownerAddress] = Owner({
        exists: true,
        subscriptionIDs: emptySubIDs,
        index: ownerIndices.length - 1
      });
      owners[ownerAddress].subscriptionIDs.push(subscriptionID);
    }

    if (subscribers[subscriberAddress].exists == true) {
      subscribers[subscriberAddress].subscriptionIDs.push(subscriptionID);
    } else {
      subscriberIndices.push(subscriberAddress);
      bytes[] memory emptySubIDs;
      subscribers[subscriberAddress] = Subscriber({
        exists: true,
        subscriptionIDs: emptySubIDs,
        index: subscriberIndices.length - 1
      });
      subscribers[subscriberAddress].subscriptionIDs.push(subscriptionID);
    }

    subscriptionIndices.push(subscriptionID);

    Subscription memory subscription = Subscription({
      id: subscriptionID,
      ownerAddress: ownerAddress,
      subscriberAddress: subscriberAddress,
      tokenAddress: tokenAddress,
      lastSettlementTime: 0,
      value: value,
      interval: interval,
      index: subscriptionIndices.length - 1,
      ownerSubscriptionIndex: owners[ownerAddress].subscriptionIDs.length - 1,
      subscriberSubscriptionIndex: subscribers[subscriberAddress].subscriptionIDs.length - 1,
      exists: true
    });

    subscriptions[subscriptionID] = subscription;

    return subscription;
  }

  function removeSubscription(bytes calldata subscriptionID) public returns (bool) {
    address subscriberAddress = msg.sender;

    require(subscriptions[subscriptionID].exists);

    Subscription memory deletedSubscription = subscriptions[subscriptionID];

    require(subscriberAddress == deletedSubscription.subscriberAddress);

    if (deletedSubscription.index != subscriptionIndices.length - 1) {
      bytes memory lastSubscriptionID = subscriptionIndices[subscriberIndices.length - 1];
      subscriptionIndices[deletedSubscription.index] = lastSubscriptionID;
      subscriptions[lastSubscriptionID].index = deletedSubscription.index;
    }

    Owner storage owner = owners[deletedSubscription.ownerAddress];

    if (deletedSubscription.ownerSubscriptionIndex != owner.subscriptionIDs.length - 1) {
      bytes memory lastOwnerSubID = owner.subscriptionIDs[owner.subscriptionIDs.length - 1];
      owner.subscriptionIDs[deletedSubscription.ownerSubscriptionIndex] = lastOwnerSubID;
      subscriptions[lastOwnerSubID].ownerSubscriptionIndex = deletedSubscription.ownerSubscriptionIndex;
    }

    Subscriber storage subscriber = subscribers[deletedSubscription.subscriberAddress];

    if (deletedSubscription.subscriberSubscriptionIndex != subscriber.subscriptionIDs.length - 1) {
      bytes memory lastSubscriberSubID = subscriber.subscriptionIDs[subscriber.subscriptionIDs.length - 1];
      subscriber.subscriptionIDs[deletedSubscription.subscriberSubscriptionIndex] = lastSubscriberSubID;
      subscriptions[lastSubscriberSubID].subscriberSubscriptionIndex = deletedSubscription.subscriberSubscriptionIndex;
    }

    delete subscriptions[subscriptionID];
    subscriptionIndices.pop();
    owner.subscriptionIDs.pop();
    subscriber.subscriptionIDs.pop();

    return true;
  }

  function getIDsByOwner(address ownerAddress) public view returns(bytes[] memory) {
    Owner memory owner = owners[ownerAddress];
    require(owner.exists);
    return owner.subscriptionIDs;
  }

  function getIDsBySubscriber(address subscriberAddress) public view returns(bytes[] memory) {
    Subscriber memory subscriber = owners[subscriberAddress];
    require(subscriber.exists);
    return subscriber.subscriptionIDs;
  }
}
