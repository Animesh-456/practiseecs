FROM node:18-alpine as build 
WORKDIR /app
COPY package.json ./
RUN npm install
COPY . .


FROM node:18-alpine
WORKDIR /app
COPY --from=build /app ./
EXPOSE 4000
CMD ["node", "index.js"]