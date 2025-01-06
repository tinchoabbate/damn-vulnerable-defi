const { ethers } = require("ethers");

function hexToAscii(hex) {
  let ascii = "";
  for (let i = 0; i < hex.length; i += 2) {
    ascii += String.fromCharCode(parseInt(hex.substr(i, 2), 16));
  }
  return ascii;
}

function decodeBase64(base64Str) {
  // Decode Base64 to ASCII
  return atob(base64Str);
}

const leakedInformation = [
  "4d 48 68 6a 4e 6a 63 34 5a 57 59 78 59 57 45 30 4e 54 5a 6b 59 54 59 31 59 7a 5a 6d 59 7a 55 34 4e 6a 46 6b 4e 44 51 34 4f 54 4a 6a 5a 47 5a 68 59 7a 42 6a 4e 6d 4d 34 59 7a 49 31 4e 6a 42 69 5a 6a 42 6a 4f 57 5a 69 59 32 52 68 5a 54 4a 6d 4e 44 63 7a 4e 57 45 35",
  "4d 48 67 79 4d 44 67 79 4e 44 4a 6a 4e 44 42 68 59 32 52 6d 59 54 6c 6c 5a 44 67 34 4f 57 55 32 4f 44 56 6a 4d 6a 4d 31 4e 44 64 68 59 32 4a 6c 5a 44 6c 69 5a 57 5a 6a 4e 6a 41 7a 4e 7a 46 6c 4f 54 67 33 4e 57 5a 69 59 32 51 33 4d 7a 59 7a 4e 44 42 69 59 6a 51 34",
];

leakedInformation.forEach((leak) => {
  hexStr = leak.split(` `).join(``).toString();

  const asciiStr = hexToAscii(hexStr);
  const decodedStr = decodeBase64(asciiStr);
  const privateKey = decodedStr;
  console.log("Private Key:", privateKey);

  // Create a wallet instance from the private key
  const wallet = new ethers.Wallet(privateKey);

  // Get the public key
  const address = wallet.address;
  console.log("Public Key:", address);
});
