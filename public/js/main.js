(function ($, undefined) {


    var auth_header = $.cookie("access_token");
    console.log(auth_header, location.pathname);

    /*
     $.ajax({
     url: "/api/orgs",
     success: function(data){
     console.log(data);
     var org = null;
     for( var i in data) {
     org = data[i];
     $('body').append("<p>org name="+ org["name"] +"</p>")
     }

     }
     });


     $(".org-container").each(function(i,n){
     var guid = $(n).data("guid");
     $.ajax({
     url: "/api/org/"+guid+"/apps",
     success: function(data){
     console.log(data);
     var app = null;
     for( var i in data) {
     app = data[i];
     $(n).append("<p>app name="+ app["name"] +"</p>")
     }

     }
     });
     });
     */


    $("#create-app-page div.type-item").on("click", function (e) {
        //console.log($(this).siblings());
        //alert("1");
        $(this).siblings().removeClass("selected");
        $(this).addClass("selected");
    });

    $("#create-app-page form").on("submit", function (e) {
        $("#app-buildpack").val($("div.type-item.selected").data("buildpack"));
    });

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

    $("#model .cancel").on("click", function (e) {
        $("#model, #model-mask").hide();
    });


    if ($("#instances-area").size()) {

        $.ajax({
            url: '/api/app/' + GLOBAL.app_guid + '/instances',
            beforeSend: function () {
                $("#instances-area").html("querying...");
            },
            success: function (data) {
                if (data["instances"].length) {
                    var html = "";
                    for (var i in data["instances"]) {
                        console.log(i, data["instances"][i]);
                        html += "<p>" + data["instances"][i]["id"] + "</p>";
                        html += "<p>" + data["instances"][i]["manifest"]["state"] + "</p>";
                    }

                    $("#instances-area").html(html);
                }
            }
        });


    }

    $(".app-row").each(function (i, n) {

        setTimeout(function () {
            $.ajax({
                url: '/api/app/' + n.id + '/instances',
                timeout: 5000,
                success: function (data) {
                    if (data["instances"].length ) {
                        if (data["healthy?"]) {
                            var className = "running";
                        } else {
                            var className = "alert";
                        }

                        $(n).find(".status").addClass(className);
                    }
                },
                error: function () {
                    $(n).find(".status").html("Timeout");
                }
            });
        }, 0);

    });


})(jQuery);

