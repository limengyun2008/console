(function ($, undefined) {


    $("#create-app-page div.type-item").on("click", function (e) {
        //console.log($(this).siblings());
        //alert("1");
        $(this).siblings().removeClass("selected");
        $(this).addClass("selected");
    });

    $("#create-app-page form").on("submit", function (e) {
        $("#app-buildpack").val($("div.type-item.selected").data("buildpack"));


        $.ajax({
            url: '/app/create',
            method: "POST",
            data: {
                "buildpack" : $("#app-buildpack").val(),
                "name" : $("#app-name").val(),
                "org" : $("#app-org").val()
            },
            success: function (data) {
                $("#model .wrp").empty();
                $("#model, #model-mask").show();
                $("#model .wrp").append("<p>已发送至任务队列</p>");

                queryLog(data.app_guid);
            }
        });

        return false;
    });

    var queryLog = function (app_guid) {
        var timer = function () {

            $.ajax({
                url: '/api/app/' + app_guid + '/create_log',
                success: function (data) {
                    for(var i in data.logs) {
                        $("#model .wrp").append("<p>"+ data.logs[i] +"</p>");
                        if ( data.finished ){
                            setTimeout( function(){
                                location.href = "/app/" + app_guid;
                            }, 2000);
                        }
                    }
                    setTimeout( timer, 2000);
                },
                error : function (data) {

                }



            });
        };
        timer();
    };




    $("#app-page .menu-item").on("click", function (e) {
        //console.log($(this).siblings());
        //alert("1");
        $(this).siblings().removeClass("selected");
        $(this).addClass("selected");

        var active = $(this).data("tab");
        $("#app-page .contents div.tab-content").removeClass("active");
        $("#" + active).addClass("active");
    });

    $("#delete-app").on("click", function (e) {
        $("#model, #model-mask").show();
    });

    $("#model .submit").on("click", function (e) {
        $.ajax({
            url: '/app/' + GLOBAL.app_guid,
            method: "POST",
            data: {"action":"delete"},
            success: function (data) {
                location.href = "/";
            }
        });
    });

    $("#model .cancel").on("click", function (e) {
        $("#model, #model-mask").hide();
    });

    $("#revision").on("focus", function (e) {
        $.ajax({
            url: '/api/app/' + GLOBAL.app_guid + '/svnlog',
            beforeSend: function () {
                $(".update-version .tip").html("<li><img src='/image/loader.gif' /></li>").show();
            },
            success: function (data) {
                presentSvnLog(data);

            }

        });
    });

    $(".update-version .tip").on("click", "li", function (e) {
        console.log($(this).data("revision"));
        $("#revision").val($(this).data("revision"));
        $(".update-version .tip").hide();
    });

    if ($("#instances-area").size()) {
        var times = 0;
        var timer = function () {
            var result = false;
            $.ajax({
                url: '/api/app/' + GLOBAL.app_guid + '/stats',
                beforeSend: function () {
                    //$("#instances-area").html("querying...");
                },
                success: function (data) {
                    var result =  presentAppInstances(data);
                    if (!result) {
                        times++;
                        if (times < 10) {
                            setTimeout( timer, 3000);
                        } else {
                            $("#instances-area").html("get instances info failed. please refresh this page.");
                        }

                    }

                }

            });
        };
        timer();
    }

    $(".app-row").each(function (i, n) {

        setTimeout(function () {
            $.ajax({
                url: '/api/app/' + n.id + '/stats',
                timeout: 5000,
                success: function (data) {
                    var className = "alert";

                    if (ifAppHeahlthy(data)) {
                        className = "running";
                    }

                    $(n).find(".status").addClass(className);

                },
                error: function () {
                    $(n).find(".status").html("Timeout");
                }
            });
        }, 0);

    });

    var ifAppHeahlthy = function (data) {
        if (data.hasOwnProperty("stats")) {
            return data.stats;
        }
        var running = 0;
        var total = 0;
        for (var i in data) {

            total++;
            if (data[i].state == "RUNNING") {
                running++;
            }
        }
        return running == total;
    };

    var presentAppInstances = function (data) {
        console.log("presentAppInstances");
        if (data.hasOwnProperty("stats")) {
            $("#instances-area").html("no running instances");
        } else {
            var html = "<table>" +
                "<thead>" +
                "<tr>" +
                    "<th>#</th>" +
                    '<th class="right">Status</th>' +
                    '<th class="right">CPU</th>' +
                    '<th class="right">Memory</th>' +
                    '<th class="right">Disk</th>' +
                "</tr>" +
                "</thead>" +
            "<tbody>" ;
            console.log(data);
            for (var i in data ) {
                if (data[i].state == "DOWN") {

                    return false;
                }
                var tr = "<tr>";
                var tmp = '<td>{{key}}</td>'
                tr += tmp.replace('{{key}}', i);
                tr += tmp.replace('{{key}}', data[i].state);
                tr += tmp.replace('{{key}}', data[i].stats.usage.cpu) ;
                tr += tmp.replace('{{key}}', data[i].stats.usage.mem / (1024 * 1024) + "MB" );
                tr += tmp.replace('{{key}}', data[i].stats.usage.disk / (1024 * 1024) + "MB");
                tr += "</tr>";
                html += tr;
            }
            html += "</tbody></html>" ;
            $("#instances-area").html(html);

        }
        return true;
    };

    var presentSvnLog = function (data) {
        var html = "";
        for (var i=0; i< data.length; i++) {
            var tmp = "<li data-revision='{{key}}'>{{value}}</li>";
            var t = data[i].revision  + " "+ data[i].date + "<br/>" +
                data[i].msg;
            html += tmp.replace("{{key}}", data[i].revision).replace("{{value}}", t);


        }
        $(".update-version .tip").html(html);
    };

    $(function () {
        fixFooterPosition();

        $(window).bind("resize", fixFooterPosition);
    });

    function fixFooterPosition () {
        var w_h = $(window).height();
        var d_h = $("html").height();
        var c_h = $(".main").height();
        console.log(w_h,d_h);

        if ( w_h > d_h) {
            $(".main").height(w_h - d_h + c_h);
        }
    }
})(jQuery);

