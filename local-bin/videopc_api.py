#!/usr/bin/env python3

from os import system

from fastapi import FastAPI

api = FastAPI()

with open("/etc/videopc_api_key", "r", encoding="utf-8") as api_file_reader:
    SECRET = api_file_reader.read().strip()


@api.get("/" + SECRET + "/test_connection")
async def test_connection():
    # TODO: check if daemons are running
    return {"api_online": 1}


@api.get("/" + SECRET + "/input/pulpit")
def switch_to_pulpit_in():
    system("hyprctl dispatch workspace 1")
    return {"success": 1}


@api.get("/" + SECRET + "/input/rtmp")
def switch_to_rtmp_in():
    system("hyprctl dispatch workspace 2")
    return {"success": 1}


@api.get("/" + SECRET + "/input/black_screen")
def switch_to_blackscreen():
    system("hyprctl dispatch workspace 3")
    return {"success": 1}


@api.get("/" + SECRET + "/power/suspend")
def suspend_videopc():
    system("systemctl suspend")
    return {"success": 1}


@api.get("/" + SECRET + "/power/shutdown")
def shutdown_videopc():
    system("shutdown now")
    return {"success": 1}


@api.get("/" + SECRET + "/power/reboot")
def reboot_videopc():
    system("reboot")
    return {"success": 1}
