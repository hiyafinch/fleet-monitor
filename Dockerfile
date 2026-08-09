FROM node:22-alpine
WORKDIR /app
# build tools needed for better-sqlite3 native compilation
RUN apk add --no-cache python3 make g++
COPY package*.json ./
RUN npm install
COPY . .
RUN mkdir -p data
CMD ["node", "src/ws-bridge/index.js"]
