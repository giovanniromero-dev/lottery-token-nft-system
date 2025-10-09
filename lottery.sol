// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts@4.5.0/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@4.5.0/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@4.5.0/access/Ownable.sol";

contract lottery is ERC20, Ownable {
    // ===========================
    // Token management
    // ===========================

    // Address of the project’s NFT contract
    address public nft;

    // Constructor
    constructor() ERC20("Lottery", "LTR"){
        _mint(address(this), 1000);
        nft = address(new mainERC721());
    }

    // Lottery prize winner
    address public winner;

    // User registry
    mapping(address => address) public user_contract;

    // Token price
    function tokenPrice(uint _numTokens) internal pure returns (uint256){
        return _numTokens * (1 ether);
    }

    // ERC-20 token balance of a user
    function tokenBalance(address _account) public view returns (uint256){
        return balanceOf(_account);
    }

    // ERC-20 token balance of the Smart Contract
    function tokenBalanceSC() public view returns (uint256){
        return balanceOf(address(this));
    }

    // Ether balance of the Smart Contract
    function etherBalanceSC() public view returns (uint256){
        return address(this).balance / 10**18;
    }

    // Mint new ERC-20 tokens
    function mint(uint _amount) public onlyOwner {
        _mint(address(this), _amount);
    }

    // User registration
    function register() internal {
        address addr_personal_contract = address(new ticketsNFTs(msg.sender, address(this), nft));
        user_contract[msg.sender] = addr_personal_contract;
    }

    // Information about a user
    function userInfo(address _account) public view returns (address){
        return user_contract[_account];
    }

    // Buy ERC-20 tokens
    function buyTokens(uint256 _numTokens) public payable {
        // Register the user
        if(user_contract[msg.sender] == address(0)){
            register();
        }
        // Establish the cost of the tokens
        uint256 cost = tokenPrice(_numTokens);
        // Check if the user pays enough ETH
        require(msg.value >= cost, "Buy fewer tokens or pay with more ethers");
        // Check the available ERC-20 tokens
        uint256 balance = tokenBalanceSC();
        require(_numTokens <= balance, "Buy fewer tokens");
        // Refund extra ETH
        uint256 returnValue = msg.value - cost;
        payable(msg.sender).transfer(returnValue);
        // Transfer tokens to the user
        _transfer(address(this), msg.sender, _numTokens);
    }

    // Return tokens to the Smart Contract
    function returnTokens(uint _numTokens) public payable {
        require(_numTokens > 0, "You must return more than 0 tokens");
        require(_numTokens <= tokenBalance(msg.sender), "You dont have enough tokens to return");
        _transfer(msg.sender, address(this), _numTokens);
        payable(msg.sender).transfer(tokenPrice(_numTokens));
    }

    // =======================================
    // Lottery management
    // =======================================

    // Price of a lottery ticket (in ERC-20 tokens)
    uint public ticketPrice = 5;
    // Mapping: person who buys tickets -> ticket numbers
    mapping(address => uint []) personTickets;
    // Mapping: ticket -> winner
    mapping(uint => address) ticketDNA;
    // Random number nonce
    uint randNonce = 0;
    // All purchased tickets
    uint [] purchasedTickets;

    // Buy lottery tickets
    function buyTicket(uint _numTickets) public {
        uint totalPrice = _numTickets * ticketPrice;
        require(totalPrice <= tokenBalance(msg.sender),
                "Not enough tokens");
        _transfer(msg.sender, address(this), totalPrice);
        
        for (uint i = 0; i < _numTickets; i++){
            uint random = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, randNonce))) % 10000;
            randNonce++;
            // Store tickets linked to the user
            personTickets[msg.sender].push(random);
            // Store all purchased tickets
            purchasedTickets.push(random);
            // Assign DNA of the ticket to a user
            ticketDNA[random] = msg.sender;
            // Mint an NFT for the ticket number
            ticketsNFTs(user_contract[msg.sender]).mintTicket(msg.sender, random);
        }
    }

    // View a user’s tickets
    function yourTickets(address _owner) public view returns(uint [] memory){
        return personTickets[_owner];
    }

    // Generate the lottery winner
    function generateWinner() public onlyOwner {
        uint length = purchasedTickets.length;
        require(length > 0, "No tickets purchased");
        uint random = uint(uint(keccak256(abi.encodePacked(block.timestamp))) % length);
        uint chosen = purchasedTickets[random];
        winner = ticketDNA[chosen];
        // Send 95% of lottery prize to the winner
        payable(winner).transfer(address(this).balance * 95 / 100);
        // Send 5% to the contract owner
        payable(owner()).transfer(address(this).balance * 5 / 100);
    }

}

// NFT Smart Contract
contract mainERC721 is ERC721 {

    address public lotteryAddress;
    constructor() ERC721("Lottery", "LOT"){
        lotteryAddress = msg.sender;
    }

    // Mint NFTs
    function safeMint(address _owner, uint256 _ticket) public {
        require(msg.sender == lottery(lotteryAddress).userInfo(_owner),
                "You dont have permission to execute this function");
        _safeMint(_owner, _ticket);
    }

}

contract ticketsNFTs {

    // Owner’s relevant data
    struct Owner {
        address ownerAddress;
        address parentContract;
        address nftContract;
        address userContract;
    }
    Owner public ownerData;

    // Constructor (child contract)
    constructor(address _owner, address _parentContract, address _nftContract){
        ownerData = Owner(_owner, _parentContract, _nftContract, address(this));
    }

    // Convert lottery ticket numbers into NFTs
    function mintTicket(address _owner, uint _ticket) public {
        require(msg.sender == ownerData.parentContract, 
                "You dont have permission to execute this function");
        mainERC721(ownerData.nftContract).safeMint(_owner, _ticket);
    }

}
