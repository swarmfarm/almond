# SwarmFarm Paddock Recorder Updater Deployment on Fly.io

This guide explains how to deploy the SwarmFarm Paddock Recorder updater server to Fly.io.

## Prerequisites

1. **Fly.io CLI**: Install flyctl from https://fly.io/docs/hands-on/install-flyctl/
2. **Fly.io Account**: Sign up at https://fly.io
3. **GitHub Token**: Personal access token with `repo` permissions for your Electron app repository

## Quick Deployment

1. **Login to Fly.io**:
   ```bash
   flyctl auth login
   ```

2. **Set Required Secrets**:
   ```bash
   flyctl secrets set TOKEN=your_github_token
   flyctl secrets set REPOSITORY=paddock-recorder
   flyctl secrets set ACCOUNT=swarmfarm-robotics
   flyctl secrets set URL=https://swarmfarm-paddock-recorder-updater.fly.dev
   ```

3. **Optional Secrets**:
   ```bash
   flyctl secrets set PRE=true  # Enable pre-release support
   ```

4. **Deploy**:
   ```bash
   ./deploy.sh
   ```

## Manual Deployment

If you prefer to deploy manually:

1. **Build the application**:
   ```bash
   bun run build
   ```

2. **Deploy to Fly.io**:
   ```bash
   flyctl deploy
   ```

## Environment Variables

The application requires these environment variables:

- `TOKEN` (required): GitHub personal access token with repo permissions
- `REPOSITORY` (required): Name of your Electron app repository
- `ACCOUNT` (required): GitHub username or organization name
- `URL` (required): Base URL of your deployed app
- `PRE` (optional): Set to "true" to enable pre-release support
- `NODE_ENV` (auto-set): Set to "production" in fly.toml
- `PORT` (auto-set): Port number (handled by Fly.io)

## API Endpoints

Once deployed, your app will be available at `https://swarmfarm-paddock-recorder-updater.fly.dev` with these endpoints:

- `GET /version` - Get latest version information
- `GET /download` - Auto-detect platform and download
- `GET /download/:platform` - Platform-specific download (mac, windows, linux)
- `GET /update/:platform/:version` - Check for updates from specific version
- `GET /releases` - Get release notes

## Configuration Changes from Docker Compose

Key differences from Docker Compose deployment:

1. **Environment Variables**: Set as Fly.io secrets instead of compose file
2. **Build System**: Uses Bun instead of npm for better performance
3. **Port**: Automatically configured by Fly.io (internal port 5000)
4. **HTTPS**: Automatically handled by Fly.io
5. **Scaling**: Auto-start/stop machines based on traffic

## Troubleshooting

1. **Check logs**:
   ```bash
   flyctl logs
   ```

2. **Check app status**:
   ```bash
   flyctl status
   ```

3. **Scale if needed**:
   ```bash
   flyctl scale count 2
   ```

4. **Update secrets**:
   ```bash
   flyctl secrets set TOKEN=new_token
   ```

## GitHub Token Setup

1. Go to GitHub Settings > Developer settings > Personal access tokens
2. Generate a new token with `repo` scope
3. Copy the token and set it as the `TOKEN` secret

## Repository Structure

Your GitHub repository should contain Electron app releases with assets for different platforms:
- Windows: `.exe` files
- macOS: `.dmg` files (non-update) and `.zip` files (updates)
- Linux: `.AppImage` or similar files

The server will automatically detect and serve the appropriate files based on the user's platform.
