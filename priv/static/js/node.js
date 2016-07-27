var event_types = ['do', 'humidity', 'temperature', 'ph', 'water_temperature'];

function WebSocketManager(ws){
    this.ws = ws;
    this.handlers = [];
    var self = this;
    this.ws.onmessage = function(evt){
        var evnt = JSON.parse(evt.data)
        for(var h in self.handlers){
            self.handlers[h][1].call(self.handlers[h][0], evnt);
        }
    }
}

WebSocketManager.prototype.add_handler = function(obj, handler){
    this.handlers.push([obj, handler])
}

WebSocketManager.prototype.send = function(message){
    this.ws.send(JSON.stringify(message));
}

function Message(type, data, id){
    this.type = type;
    this.data = data;
    this.id = id;
}

function Node(obj, parent, user_id, websocket){
    this.data = obj;
    this.id = this.data.id;
    this.ws = websocket;
    this.start = null;
    this.user_id = user_id;
    this.last = {};
    this.events = {};
    this.charts = {};
    this.dom(parent);
    this.graph();
    this.websocket();
    this.stream();
    this.rendered_charts = 0;
}

Node.prototype.dom = function(parent){
    var elem = "<div class=\"col-sm-6 col-md-6\"> \
            <div class=\"thumbnail\"> \
                <img id=\"stream"+this.id+"\"> \
                <div class=\"caption\"> \
                    <div class=\"messages\" id=\"messages"+this.id+"\"></div> \
                    <div class=\"btn-group\" role=\"group\" > \
                        <button type=\"button\" class=\"btn btn-default\" id=\"on"+this.id+"\">ON</button> \
                        <button type=\"button\" class=\"btn btn-default\" id=\"off"+this.id+"\">OFF</button> \
                    </div> \
                </div> \
            </div> \
        </div>";
    var self = this;
    $(parent).append(elem);
    $("#on"+this.id).click(function(){
        self.on();
    });
    $("#off"+this.id).click(function(){
        self.off();
    });
}

Node.prototype.graph = function(){
    var self = this;
    var counter = 0;
    for(var i in event_types){
        var s = event_types[i];
        $("#messages"+this.id).append("<svg id='"+s+"'></svg>");
        this.events[s] = [];
        nv.addGraph(function() {
            var chart = nv.models.lineChart()
                .margin({left: 50, right: 20})
                .useInteractiveGuideline(true)
                .showLegend(true)
                .showYAxis(true)
                .showXAxis(false)
                .noData("Waiting for stream...");

            chart.xAxis     //Chart x-axis settings
                .tickFormat(function(d) {
                    return d3.time.format('%X')(new Date(d));
                });

            return chart;
        }, function(chart){
            self.update_charts(chart)
        });
    }
    nv.utils.windowResize(function() {
        for(var c in this.charts){
            this.charts[c].update();
        }
    });
    window.requestAnimationFrame(function(ts){
        self.update_graphs(ts);
    });
    $(window).focus(function() {
        self.reset_data();
    });
}

Node.prototype.update_charts = function(chart){
    type = event_types[this.rendered_charts];
    console.log("Adding Chart: "+type);
    this.charts[type] = chart;

    console.log(chart);
    console.log(this.charts);
    this.rendered_charts++;
}

Node.prototype.reset_data = function(){
    console.log("reset data");
    for(var k in this.events){
        this.events[k][0].values = [];
    }
}

Node.prototype.websocket = function(){
    this.send("node", "");
    this.ws.add_handler(this, this.onmessage);
}

Node.prototype.onmessage = function(evnt) {
    if(evnt.id != this.id) return;
    if(event_types.indexOf(evnt.type) == -1) return;
    this.last[evnt.type] = {x: new Date().getTime(), y: evnt.value};
};

Node.prototype.update_graphs = function(ts){
    var colors = d3.scale.category10();
    var self = this;
    if (!this.start) this.start = ts;
    window.requestAnimationFrame(function(ts){self.update_graphs(ts)});
    if(ts - this.start < 200) return;
    this.start = ts;
    var kolor = 0;
    for(var k in this.last){
        var evs = false;
        if(this.events[k].length) evs = this.events[k][0];
        if(!evs){
            evs = {key: k, values: [], color: colors.range()[kolor]};
            this.events[k].push(evs);
        }
        kolor++;
        var cp = jQuery.extend({}, this.last[k]);
        cp.x = new Date().getTime();
        evs.values.push(cp);
        if(evs.values.length > 200) evs.values.shift();
        d3.select('#messages'+this.id+' #'+k)
            .datum(this.events[k])
            .call(this.charts[k]);
    }
}

Node.prototype.send = function(type, data){
    var m = new Message(type, data, this.id);
    this.ws.send(m);
}

Node.prototype.on = function(){
    this.send("light", "on");
}

Node.prototype.off = function(){
    this.send("light", "off");
}

Node.prototype.display_event = function(evnt){
    if(evnt.type == "node_message" || evnt.type == "response") return;
    var messages = document.getElementById("messages"+this.id);
    var len = messages.childNodes.length;
    if(len > this.events.length) messages.removeChild(messages.firstChild);

    var v = evnt.value;
    try{
        v = JSON.stringify(v);
    }catch(e){
        v = v;
    }
    var e = document.createElement("div");
    e.innerHTML = evnt.type+": "+v;
    messages.appendChild(e);
    e.style.opacity = 0;
    window.getComputedStyle(e).opacity;
    e.style.opacity = 1;
}

Node.prototype.stream = function(){
    $("#stream"+this.id).attr("src", "/stream?node_id="+this.id+"&user_id="+this.user_id);
}
