module.exports = {
  apps: [
    {
      name: "new-site",
      cwd: "/opt/new-site",
      script: "scripts/run.sh",
      interpreter: "bash",
      autorestart: true,
      watch: false,
      max_memory_restart: "300M",
    },
  ],
};
