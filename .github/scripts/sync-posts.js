// TODO: Make into GitHub Action if it works as expected
const fs = require('fs');
const path = require('path');
const matter = require('gray-matter');
const { MongoClient, ServerApiVersion } = require('mongodb');
const glob = require('glob');

async function syncPosts() {
  // Create MongoDB client with recommended options
  const client = new MongoClient(process.env.MONGODB_URI, {
    serverApi: {
      version: ServerApiVersion.v1,
      strict: true,
      deprecationErrors: true,
    }
  });

  try {
    // Connect and verify connection with ping
    await client.connect();
    await client.db("admin").command({ ping: 1 });
    console.log("Successfully connected to MongoDB");

    const db = client.db('v3db');
    const postsCollection = db.collection('blog');

    // Find all markdown files
    const markdownFiles = glob.sync('blog/**/*.md');
    console.log(`Found ${markdownFiles.length} markdown files to process`);

    for (const filePath of markdownFiles) {
      const fileContent = fs.readFileSync(filePath, 'utf8');
      const { data: frontMatter, content } = matter(fileContent);
      
      // Process relative image paths to make them absolute
      const blogDir = path.dirname(filePath);
      const processedContent = content.replace(
        /!\[([^\]]*)\]\(\.\/([^)]+)\)/g,
        (match, alt, relativePath) => {
          const absolutePath = path.join(blogDir, relativePath);
          const repoRelativePath = absolutePath.replace(/^blog\//, '');
          return `![${alt}](/${repoRelativePath})`;
        }
      );

      // Validate required frontmatter fields
      if (!frontMatter.title || !frontMatter.date) {
        console.warn(`Warning: Missing required frontmatter in ${filePath}`);
      }

      const post = {
        slug: path.basename(path.dirname(filePath)),
        path: filePath,
        content: processedContent,
        ...frontMatter,
        lastUpdated: new Date(),
        syncedAt: new Date(),
      };

      // Upsert the post
      const result = await postsCollection.updateOne(
        { path: filePath },
        { $set: post },
        { upsert: true }
      );

      console.log(
        `Processed ${filePath}: ${
          result.upsertedCount ? 'inserted' : 'updated'
        }`
      );
    }

    console.log('Blog sync completed successfully');
  } catch (error) {
    console.error('Error syncing posts:', error);
    process.exit(1);
  } finally {
    await client.close();
    console.log('MongoDB connection closed');
  }
}

// Run the sync function
syncPosts().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});