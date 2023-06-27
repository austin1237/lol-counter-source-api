const puppeteer = require("puppeteer-core");
const chromium = require("@sparticuz/chromium");
const champions = require('./src/champions');

async function getCounters(championName) {
  const browser = await puppeteer.launch({
    args: process.env.IS_LOCAL ? puppeteer.defaultArgs() : chromium.args,
    defaultViewport: chromium.defaultViewport,
    executablePath: process.env.IS_LOCAL
      ? "/tmp/localChromium/chromium/mac-1162696/chrome-mac/Chromium.app/Contents/MacOS/Chromium"
      : await chromium.executablePath(),
    headless: process.env.IS_LOCAL ? false : chromium.headless,
  });

  const page = await browser.newPage();
  
  await page.goto(`${process.env.BASE_COUNTER_URL}/${championName}/counter`);
  const counters = await page.evaluate(() => {
    const container = document.querySelector('div.counters-list.best-win-rate');
    
    const championNameDivs = container.querySelectorAll('div.champion-name');
    const winRateDivs = container.querySelectorAll('div.win-rate');
    
    const names = Array.from(championNameDivs).map(div => div.textContent.trim());
    const winRates = Array.from(winRateDivs).map(div => div.textContent.trim());

    
    return {champions: names, winRates: winRates}
  });
  
  await browser.close();
  return counters;
}



exports.handler = async function (event, context) {
  const champName = event.queryStringParameters.champion;
  if (champions.indexOf(champName) === -1){
    console.log('not found')
    const response = {
      "statusCode": 404,
      "headers": {},
      "body": JSON.stringify(`champion ${champName} not found`),
      "isBase64Encoded": false
    };
    return response
  }
  const counters = await getCounters(champName);
  console.log('counters', counters)
  const response = {
    "statusCode": 200,
    "headers": {},
    "body": JSON.stringify(counters),
    "isBase64Encoded": false
  };
  return response
};

// test it locally 
exports.handler({
  queryStringParameters:{
    champion: 'swain',
  }
});
