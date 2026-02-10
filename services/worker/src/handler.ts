export const handler = async (event: any) => {
  console.log(JSON.stringify({ msg: "worker invoked", event }, null, 2));
  return {};
};
