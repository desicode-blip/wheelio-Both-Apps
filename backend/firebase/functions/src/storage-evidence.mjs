export async function readObjectMetadata(file) {
  try { const [metadata] = await file.getMetadata(); return metadata; }
  catch (error) { if (Number(error.code) === 404) return null; throw error; }
}
