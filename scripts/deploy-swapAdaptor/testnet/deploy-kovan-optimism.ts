import { deploy } from "../deploy-utils";

(async () => {
  const config = {
    _swapRouter: "0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45",
    nativeWrapAddress: "0x4200000000000000000000000000000000000006" 
  };
  await deploy(config);
})();
