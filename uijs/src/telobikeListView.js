var uijs = require('uijs');
var positioning = uijs.positioning;
var scroller = uijs.scroller;
var box = uijs.box;
var controls = require('uijs-controls');
var telobikeListItem = require('./telobikeListItem');
//var telobikeClickedListItem = require('./telobikeClickedListItem');
var listview = controls.listview;

function stripes() {
  var obj = listview({
    items:[],
    onBindBoxItem: telobikeListItem,
    itemHeight:68,
    width:function(){return this.root().width;},
  });

  var model = require('./model').createModel();

  model.on('update', function() {

    obj.items = model.stations;//.slice(0,7);//.sort(function(a,b){ return a.distance - b.distance; });
  });
  
  /*obj.ondraw = function(ctx) {
    ctx.fillStyle = 'gray';
    ctx.fillRect(0, 0, this.width, this.height);
    var curr_y = 0;
    var h = 100;

    ctx.strokeStyle = 'black';
    ctx.fillStyle = 'blue';
    ctx.font = '20px Helvetica';
    var i = 0;
    while (curr_y < this.height) {
      ctx.strokeRect(0, curr_y, this.width, h);
      ctx.fillText(i.toString(), 20, curr_y + 50);
      curr_y += h;
      i++;
    }
  };*/
  return obj;
}



//var s = scroller({
  //content:stripes(),
//});

//s.content = stripes();
//s.height = 1000;

module.exports = stripes();