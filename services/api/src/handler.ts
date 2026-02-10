export const handler = async (event: any) => {
  console.log(JSON.stringify({ msg: "api invoked", event }, null, 2));
  return {
    statusCode: 202,
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ status: "accepted" }),
  };
};
