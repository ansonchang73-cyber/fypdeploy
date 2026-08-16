module.exports = (req, res) => {
  return res.status(200).json({ reply: "Diagnostic: Vercel is successfully running the Javascript file.", action: null });
};