FROM node:23-alpine

RUN apk add --no-cache bash

COPY . /app
WORKDIR /app
RUN npm install

CMD npm start
